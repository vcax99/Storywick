import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(Narrator.self) private var narrator
    @Query(sort: \Story.createdAt, order: .reverse) private var stories: [Story]
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue

    @State private var draft = ""
    @State private var openStoryID: PersistentIdentifier?
    @FocusState private var editorFocused: Bool

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .dark }
    private var wordCount: Int { TextStats.wordCount(draft) }
    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isOverLimit: Bool { wordCount > AppConfig.wordLimit }
    private var canListen: Bool { !trimmed.isEmpty && !isOverLimit }

    private func story(for id: PersistentIdentifier) -> Story? {
        stories.first { $0.persistentModelID == id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        titleBlock
                        if narrator.isActive, let playing = nowPlayingStory {
                            miniPlayer(playing)
                        }
                        editorCard
                        listenButton
                        if !stories.isEmpty { recentSection }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { appearanceButton }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editorFocused = false }
                }
            }
            .navigationDestination(item: $openStoryID) { id in
                if let story = story(for: id) {
                    ReaderView(story: story)
                }
            }
        }
    }

    // MARK: Pieces

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                StorywickMark(animated: true)
                    .frame(width: 38, height: 38)
                    .glow(Theme.glow, radius: 8)
                Text("Storywick")
                    .font(.display(40, weight: .semibold, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                    .glow(Theme.glow, radius: 16)
            }
            Text("Paste a chapter. Pick a voice. Listen.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 4)
    }

    private var editorCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft)
                    .focused($editorFocused)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 220)
                    .padding(12)

                if draft.isEmpty {
                    Text("Paste your chapter here…")
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.textFaint)
                        .padding(.top, 20)
                        .padding(.leading, 17)
                        .allowsHitTesting(false)
                }
            }

            Rectangle().fill(Theme.stroke).frame(height: 1)

            HStack {
                Text("\(wordCount) / \(AppConfig.wordLimit) words")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(counterColor)
                Spacer()
                if isOverLimit {
                    Label("\(wordCount - AppConfig.wordLimit) over", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                } else if !trimmed.isEmpty {
                    Button("Clear") { draft = "" }
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke, lineWidth: 1))
    }

    private var listenButton: some View {
        Button {
            startListening()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text("Listen").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .glow(Theme.glow, radius: 18, active: canListen)
        .opacity(canListen ? 1 : 0.4)
        .disabled(!canListen)
        .animation(.easeInOut(duration: 0.2), value: canListen)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.display(21, weight: .medium, relativeTo: .title3))
                .foregroundStyle(Theme.textPrimary)

            ForEach(stories) { story in
                Button { openStoryID = story.persistentModelID } label: {
                    RecentCard(story: story)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { delete(story) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Text("The last \(AppConfig.historyLimit) chapters are kept — the oldest drops off.")
                .font(.caption)
                .foregroundStyle(Theme.textFaint)
                .padding(.top, 2)
        }
    }

    private var nowPlayingStory: Story? {
        guard let id = narrator.loadedStoryID else { return nil }
        return stories.first { $0.persistentModelID == id }
    }

    private func miniPlayer(_ story: Story) -> some View {
        Button { openStoryID = story.persistentModelID } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.accent)
                    .glow(Theme.glow, radius: 6, active: narrator.isSpeaking && !narrator.isPaused)
                VStack(alignment: .leading, spacing: 1) {
                    Text(story.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(narrator.isPaused ? "Paused" : "Now narrating")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    narrator.togglePlayPause()
                } label: {
                    Image(systemName: narrator.isSpeaking && !narrator.isPaused ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var appearanceButton: some View {
        Button {
            withAnimation { appearanceRaw = appearance.toggled.rawValue }
        } label: {
            Image(systemName: appearance.symbol)
        }
        .accessibilityLabel("Switch to \(appearance.toggled.label) theme")
    }

    private var counterColor: Color {
        if isOverLimit { return Theme.warning }
        if Double(wordCount) > Double(AppConfig.wordLimit) * 0.9 { return Theme.warning }
        return Theme.textSecondary
    }

    // MARK: Actions

    private func startListening() {
        editorFocused = false
        let story = Story(title: derivedTitle(from: trimmed), text: trimmed)
        context.insert(story)

        let descriptor = FetchDescriptor<Story>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let all = try? context.fetch(descriptor), all.count > AppConfig.historyLimit {
            for old in all[AppConfig.historyLimit...] { context.delete(old) }
        }
        try? context.save()

        draft = ""
        openStoryID = story.persistentModelID
    }

    private func delete(_ story: Story) {
        if openStoryID == story.persistentModelID { openStoryID = nil }
        context.delete(story)
        try? context.save()
    }

    private func derivedTitle(from text: String) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? "Untitled Chapter"
        return String(firstLine.trimmingCharacters(in: .whitespaces).prefix(60))
    }
}

private struct RecentCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(story.title)
                .font(.display(18, weight: .medium, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Text(story.previewLine)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 10) {
                ProgressView(value: story.progressFraction)
                    .tint(Theme.spark)
                    .frame(maxWidth: 110)
                Text(story.progressLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
                Spacer()
                Text("\(story.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
    }
}
