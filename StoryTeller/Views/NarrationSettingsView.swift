import SwiftUI

struct NarrationSettingsView: View {
    @Bindable var narrator: Narrator
    @Environment(\.dismiss) private var dismiss

    @State private var appleVoices: [VoiceOption] = []
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var isNarrating: Bool { narrator.isSpeaking && !narrator.isPaused }

    /// Selecting a voice: if a chapter is playing it just switches live; otherwise
    /// play a short sample so you can hear it.
    private func chose() {
        narrator.applyLiveChange()
        if !isNarrating { narrator.previewVoice() }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        engineSection
                        voiceSection
                        EqualizerSection
                        previewButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Narration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { appleVoices = VoiceCatalog.voices() }
            .onDisappear { narrator.stopPreview() }
        }
    }

    // MARK: Engine

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Engine")
            ForEach(SpeechEngineKind.allCases) { kind in
                let disabled = kind == .kokoro && !narrator.kokoroAvailable
                Button {
                    narrator.engineKind = kind
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: kind == narrator.engineKind ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(Theme.accent)
                            .font(.system(size: 18))
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(kind.label)
                                .font(.display(17, weight: .medium, relativeTo: .headline))
                                .foregroundStyle(Theme.textPrimary)
                            Text(disabled ? "Neural model unavailable on this device." : kind.blurb)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(kind == narrator.engineKind ? Theme.accent : Theme.stroke,
                                    lineWidth: kind == narrator.engineKind ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.5 : 1)
            }
        }
    }

    // MARK: Voice

    @ViewBuilder
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Voice")
            if narrator.engineKind == .kokoro {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(kokoroVoiceOptions) { voice in
                        KokoroVoiceCard(voice: voice, selected: narrator.kokoroVoice == voice.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                narrator.kokoroVoice = voice.id
                                chose()
                            }
                    }
                }
            } else {
                if appleVoices.isEmpty {
                    Text("No English voices found on this device.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(appleVoices) { voice in
                            AppleVoiceCard(voice: voice, selected: narrator.appleVoiceIdentifier == voice.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    narrator.appleVoiceIdentifier = voice.id
                                    chose()
                                }
                        }
                    }
                    Text("More voices install in Settings › Accessibility › Spoken Content › Voices.")
                        .font(.caption)
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
    }

    // MARK: Equalizer

    private var EqualizerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionTitle("Equalizer")
                Spacer()
                Button {
                    narrator.resetEqualizer()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 14) {
                VerticalDial(
                    title: "Speed",
                    value: $narrator.speed,
                    range: 0.5...2.0,
                    display: { String(format: "%.2f×", $0) },
                    onCommit: { narrator.applyLiveChange() }
                )
                if narrator.engineKind == .apple {
                    VerticalDial(
                        title: "Pitch",
                        value: $narrator.pitch,
                        range: 0.5...2.0,
                        display: { String(format: "%.2f", $0) },
                        onCommit: { narrator.applyLiveChange() }
                    )
                }
                VerticalDial(
                    title: "Volume",
                    value: $narrator.volume,
                    range: 0.0...1.0,
                    display: { "\(Int(($0 * 100).rounded()))%" },
                    onCommit: { narrator.applyLiveChange() }
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
        }
    }

    private var previewButton: some View {
        Button {
            if narrator.isPreviewing { narrator.stopPreview() } else { narrator.previewVoice() }
        } label: {
            HStack(spacing: 8) {
                if narrator.isPreviewing {
                    ProgressView().tint(Theme.accent)
                    Text("Generating…")
                } else {
                    Image(systemName: "play.circle.fill")
                    Text("Preview voice")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.display(21, weight: .medium, relativeTo: .title3))
            .foregroundStyle(Theme.textPrimary)
    }
}

private struct KokoroVoiceCard: View {
    let voice: KokoroVoiceOption
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: voice.genderSymbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accent)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            Text(voice.name)
                .font(.display(17, weight: .medium, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text("\(voice.gender) · \(voice.accent)")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Theme.accent : Theme.stroke, lineWidth: selected ? 2 : 1)
        )
        .glow(Theme.glow, radius: 10, active: selected)
    }
}

private struct AppleVoiceCard: View {
    let voice: VoiceOption
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: voice.genderSymbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accent)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            Text(voice.name)
                .font(.display(17, weight: .medium, relativeTo: .headline))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Text("\(voice.gender) · \(voice.accent)")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            if let quality = voice.quality {
                Text(quality.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accentSoft, in: Capsule())
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Theme.accent : Theme.stroke, lineWidth: selected ? 2 : 1)
        )
        .glow(Theme.glow, radius: 10, active: selected)
    }
}

private struct VerticalDial: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let display: (Float) -> String
    var onCommit: () -> Void = {}

    private let trackHeight: CGFloat = 150
    private let trackWidth: CGFloat = 6
    private let thumbSize: CGFloat = 26

    private var fraction: CGFloat {
        let span = CGFloat(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return min(max(CGFloat(value - range.lowerBound) / span, 0), 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(display(value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.textPrimary)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Theme.stroke)
                    .frame(width: trackWidth, height: trackHeight)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: trackWidth, height: max(trackWidth, fraction * trackHeight))
                Circle()
                    .fill(Theme.accent)
                    .frame(width: thumbSize, height: thumbSize)
                    .glow(Theme.glow, radius: 6)
                    .offset(y: -fraction * (trackHeight - thumbSize))
            }
            .frame(width: thumbSize, height: trackHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let y = min(max(0, trackHeight - gesture.location.y), trackHeight)
                        let f = Float(y / trackHeight)
                        value = range.lowerBound + f * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in onCommit() }
            )

            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
