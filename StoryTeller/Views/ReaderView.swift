import SwiftUI
import SwiftData
import Combine

/// Now-Playing–style player screen. The card up top shows the chapter with the
/// line being read spotlit; transport lives at the bottom. Follows the app's
/// light / dark theme, with an emerald wash either way.
struct ReaderView: View {
    let story: Story

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Environment(Narrator.self) private var narrator

    @State private var showingSettings = false
    @State private var showingMood = false
    @State private var lastScrolledParagraph = -1

    // Estimated per-sentence timeline, so the scrubber can show a clock.
    @State private var starts: [Double] = []
    @State private var durations: [Double] = []
    @State private var totalTime: Double = 0

    private let readingSize: Double = 15

    private var dark: Bool { scheme == .dark }
    private var reading: Bool { narrator.isSpeaking || narrator.isPaused }
    private var playing: Bool { narrator.isSpeaking && !narrator.isPaused }

    // MARK: Emerald wash — theme-aware, not part of Theme

    private var groundGradient: LinearGradient {
        dark
        ? LinearGradient(colors: [Color(red: 0.055, green: 0.102, blue: 0.086),
                                  Color(red: 0.031, green: 0.047, blue: 0.043)],
                         startPoint: .top, endPoint: .bottom)
        : LinearGradient(colors: [Color(red: 0.914, green: 0.961, blue: 0.937),
                                  Color(red: 0.973, green: 0.984, blue: 0.976)],
                         startPoint: .top, endPoint: .bottom)
    }

    private var cardGradient: LinearGradient {
        dark
        ? LinearGradient(colors: [Color(red: 0.086, green: 0.161, blue: 0.133),
                                  Color(red: 0.043, green: 0.094, blue: 0.078)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(colors: [.white,
                                  Color(red: 0.945, green: 0.973, blue: 0.957)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var playIconColor: Color {
        dark ? Color(red: 0.031, green: 0.047, blue: 0.043) : .white
    }
    private var dimAlpha: Double { dark ? 0.26 : 0.40 }
    private var restAlpha: Double { dark ? 0.82 : 0.88 }

    private var cardStrokeOpacity: Double {
        if playing { return dark ? 0.5 : 0.32 }
        return dark ? 0.22 : 0.14
    }
    private var cardShadow: Color {
        if playing { return Theme.accent.opacity(dark ? 0.35 : 0.18) }
        return dark ? .clear : .black.opacity(0.06)
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 14) {
                chapterTitle
                readingCard
                nowLine
                PlaybackScrubber(starts: starts, durations: durations, total: totalTime,
                                 accent: Theme.accent, faint: Theme.textFaint)
                transport
                secondaryControls
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    StorywickMark(animated: true)
                        .frame(width: 19, height: 19)
                    Text("Storywick")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .onAppear {
            story.lastOpenedAt = .now
            narrator.load(story)
            rebuildTimeline()
        }
        .onDisappear {
            persistProgress()
            try? context.save()
        }
        .onChange(of: narrator.currentIndex) { _, _ in persistProgress() }
        .onChange(of: narrator.speed) { _, _ in rebuildTimeline() }
        .onChange(of: narrator.engineKind) { _, _ in rebuildTimeline() }
        .onChange(of: narrator.sentences.count) { _, _ in rebuildTimeline() }
        .sheet(isPresented: $showingSettings) { NarrationSettingsView(narrator: narrator) }
        .sheet(isPresented: $showingMood) { MoodPickerView(narrator: narrator, story: story) }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            groundGradient
            RadialGradient(colors: [Theme.accent.opacity(dark ? 0.14 : 0.09), .clear],
                           center: .top, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }

    private var chapterTitle: some View {
        Text(story.title)
            .font(.system(.title3, design: .serif).weight(.medium))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }

    // MARK: The card — the reading view

    private var readingCard: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(story.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        paragraphRow(paragraph).id(index)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .onChange(of: narrator.currentIndex) { _, _ in
                guard narrator.isSpeaking,
                      let target = activeParagraphIndex(), target != lastScrolledParagraph else { return }
                lastScrolledParagraph = target
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardGradient, in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Theme.accent.opacity(cardStrokeOpacity), lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: dark ? 16 : 12, y: dark ? 0 : 4)
    }

    private func paragraphRow(_ paragraph: String) -> some View {
        let active = isActiveParagraph(paragraph)
        return HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(active ? Theme.spark : .clear)
                .frame(width: 3)
                .shadow(color: active ? Theme.spark.opacity(0.7) : .clear, radius: 6)
            Text(styled(paragraph))
                .font(.system(size: readingSize, design: .serif))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
    }

    /// Dim everything, spotlight the sentence being read (Apple-Music-lyrics style).
    private func styled(_ paragraph: String) -> AttributedString {
        var a = AttributedString(paragraph)
        a.foregroundColor = Theme.textPrimary.opacity(reading ? dimAlpha : restAlpha)
        if reading, let sentence = narrator.currentSentenceText, let range = a.range(of: sentence) {
            a[range].foregroundColor = Theme.textPrimary
        }
        return a
    }

    private func isActiveParagraph(_ paragraph: String) -> Bool {
        guard reading, let sentence = narrator.currentSentenceText else { return false }
        return paragraph.contains(sentence)
    }

    private func activeParagraphIndex() -> Int? {
        guard let sentence = narrator.currentSentenceText else { return nil }
        return story.paragraphs.firstIndex { $0.contains(sentence) }
    }

    private func persistProgress() {
        guard !narrator.sentences.isEmpty else { return }
        story.progressIndex = narrator.currentIndex
    }

    // MARK: Timeline estimate

    private func rebuildTimeline() {
        let wordsPerSecond: Double = {
            let base = narrator.engineKind == .kokoro ? 2.55 : 2.9
            return max(0.5, base * Double(narrator.speed))
        }()
        var st: [Double] = []
        var dur: [Double] = []
        var acc = 0.0
        for sentence in narrator.sentences {
            let words = max(1, sentence.text.split { $0 == " " || $0 == "\n" }.count)
            let d = max(0.9, Double(words) / wordsPerSecond + 0.3)
            st.append(acc)
            dur.append(d)
            acc += d
        }
        starts = st
        durations = dur
        totalTime = acc
    }

    // MARK: Now-playing line

    private var nowLine: some View {
        Group {
            if narrator.isPreparing {
                Text("Generating the voice…")
            } else if let line = narrator.currentSentenceText, reading {
                Text(line)
            } else {
                Text("Tap play to begin")
            }
        }
        .font(.subheadline)
        .foregroundStyle(Theme.textSecondary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 46) {
            transportButton("backward.fill") { narrator.skip(by: -1) }

            Button {
                narrator.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 78, height: 78)
                        .shadow(color: Theme.accent.opacity(dark ? 0.6 : 0.4), radius: dark ? 18 : 12)
                    if narrator.isPreparing {
                        ProgressView().controlSize(.large).tint(playIconColor)
                    } else {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(playIconColor)
                    }
                }
            }
            .disabled(narrator.isPreparing)

            transportButton("forward.fill") { narrator.skip(by: 1) }
        }
        .padding(.vertical, 4)
    }

    private func transportButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 26))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: Mood / voice

    private var secondaryControls: some View {
        HStack(spacing: 56) {
            Button { showingMood = true } label: {
                controlLabel(
                    icon: narrator.mood == .none ? "music.note" : "music.note.list",
                    text: "Mood",
                    tint: narrator.mood == .none ? Theme.textSecondary : Theme.spark
                )
            }
            Button { showingSettings = true } label: {
                controlLabel(icon: "slider.horizontal.3", text: "Voice", tint: Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func controlLabel(icon: String, text: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 17))
            Text(text).font(.caption2)
        }
        .foregroundStyle(tint)
    }
}

// MARK: - Scrubber

/// The progress bar. Its thumb is the Storywick mark, turning clockwise while
/// playback runs. Owns its own tick so the reading card above doesn't re-render
/// four times a second.
private struct PlaybackScrubber: View {
    @Environment(Narrator.self) private var narrator

    let starts: [Double]
    let durations: [Double]
    let total: Double
    let accent: Color
    let faint: Color

    @State private var elapsed: Double = 0
    /// Non-nil only while a drag is in progress (0...1 of the bar).
    @State private var dragFraction: Double?

    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private let thumb: CGFloat = 26

    private var playing: Bool { narrator.isSpeaking && !narrator.isPaused }
    private var enabled: Bool { narrator.sentences.count >= 2 }
    private var span: Double { max(total, 1) }

    private var fraction: Double {
        if let d = dragFraction { return d }
        return min(max(elapsed / span, 0), 1)
    }
    private var shownTime: Double {
        dragFraction.map { $0 * span } ?? min(elapsed, span)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let usable = max(geo.size.width - thumb, 1)
                let x = thumb / 2 + usable * fraction

                ZStack(alignment: .leading) {
                    Capsule().fill(faint.opacity(0.3)).frame(height: 4)
                    Capsule().fill(accent).frame(width: max(x, thumb / 2), height: 4)
                    SpinningMark(active: playing && dragFraction == nil, size: thumb)
                        .shadow(color: accent.opacity(0.45), radius: 5)
                        .position(x: x, y: geo.size.height / 2)
                }
                .frame(height: thumb)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard enabled else { return }
                            dragFraction = min(max((v.location.x - thumb / 2) / usable, 0), 1)
                        }
                        .onEnded { _ in
                            guard enabled, let d = dragFraction else { return }
                            let target = sentenceIndex(for: d * span)
                            elapsed = start(target)
                            dragFraction = nil
                            narrator.seek(to: target)
                        }
                )
            }
            .frame(height: thumb)
            .opacity(enabled ? 1 : 0.5)

            HStack {
                Text(clock(shownTime))
                Spacer()
                Text(clock(total))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(faint)
        }
        .onAppear { elapsed = start(narrator.currentIndex) }
        .onChange(of: narrator.currentIndex) { _, i in
            if dragFraction == nil { elapsed = start(i) }
        }
        .onChange(of: total) { _, _ in
            if dragFraction == nil { elapsed = start(narrator.currentIndex) }
        }
        .onChange(of: narrator.isSpeaking) { _, speaking in
            guard !speaking, !narrator.isPaused else { return }
            elapsed = narrator.currentIndex == 0 ? 0 : start(narrator.currentIndex)
        }
        .onReceive(tick) { _ in
            guard playing, dragFraction == nil else { return }
            let i = narrator.currentIndex
            let cap = start(i) + (durations.indices.contains(i) ? durations[i] : 0)
            elapsed = min(elapsed + 0.25, cap)
        }
    }

    private func start(_ i: Int) -> Double {
        guard starts.indices.contains(i) else { return starts.last ?? 0 }
        return starts[i]
    }

    private func sentenceIndex(for time: Double) -> Int {
        var result = 0
        for (i, s) in starts.enumerated() where s <= time { result = i }
        return result
    }

    private func clock(_ t: Double) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// The brand mark used as the scrubber thumb — turns clockwise while `active`,
/// freezes in place otherwise.
private struct SpinningMark: View {
    let active: Bool
    let size: CGFloat

    @State private var angle: Double = 0
    private let frame = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        StorywickMark()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
            .onReceive(frame) { _ in
                guard active else { return }
                angle = (angle + 3).truncatingRemainder(dividingBy: 360)
            }
    }
}
