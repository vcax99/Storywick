import SwiftUI

struct MoodPickerView: View {
    @Bindable var narrator: Narrator
    let story: Story
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        levelCard
                        VStack(alignment: .leading, spacing: 12) {
                            sectionTitle("Mood")
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(Mood.allCases) { mood in
                                    MoodChip(mood: mood, selected: narrator.mood == mood)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            story.mood = mood
                                            narrator.setMood(mood)
                                        }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Background level")
                Spacer()
                Button {
                    narrator.resetMusicLevel()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            Text("The bed always sits well under the narration — this trims it within that range.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill").foregroundStyle(Theme.textFaint)
                Slider(value: $narrator.musicLevel, in: 0...1)
                    .tint(Theme.accent)
                    .disabled(narrator.mood == .none)
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.textFaint)
            }
            .opacity(narrator.mood == .none ? 0.4 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.display(20, weight: .medium, relativeTo: .title3))
            .foregroundStyle(Theme.textPrimary)
    }
}

private struct MoodChip: View {
    let mood: Mood
    let selected: Bool

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: mood.symbol)
                .font(.system(size: 17))
                .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                .frame(height: 20)
            Text(mood.label)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(2)
                .frame(minHeight: 26, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Theme.accent : Theme.stroke, lineWidth: selected ? 2 : 1)
        )
        .glow(Theme.glow, radius: 8, active: selected)
    }
}
