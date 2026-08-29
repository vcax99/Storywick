import Foundation
import SwiftData

/// One pasted chapter. Everything lives on-device via SwiftData.
@Model
final class Story {
    var title: String
    var text: String
    var createdAt: Date
    var lastOpenedAt: Date

    /// Sentence index the listener last reached — used to resume.
    var progressIndex: Int = 0

    /// Cached at creation so the history list can show progress without re-splitting.
    var sentenceCount: Int = 0

    /// Background mood for this chapter (raw value of `Mood`).
    var moodRaw: String = Mood.mystery.rawValue

    init(title: String, text: String, createdAt: Date = .now) {
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.lastOpenedAt = createdAt
        self.progressIndex = 0
        self.sentenceCount = TextStats.sentences(text).count
        self.moodRaw = Mood.mystery.rawValue
    }

    var mood: Mood {
        get { Mood(rawValue: moodRaw) ?? .none }
        set { moodRaw = newValue.rawValue }
    }
}

extension Story {
    var wordCount: Int { TextStats.wordCount(text) }

    var paragraphs: [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var previewLine: String {
        let flattened = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        return String(flattened.prefix(160))
    }

    var progressFraction: Double {
        guard sentenceCount > 1 else { return 0 }
        return min(Double(progressIndex) / Double(sentenceCount - 1), 1)
    }

    var isFinished: Bool {
        sentenceCount > 0 && progressIndex >= sentenceCount - 1
    }

    var progressLabel: String {
        if progressIndex == 0 { return "Not started" }
        if isFinished { return "Finished" }
        return "\(Int(progressFraction * 100))% in"
    }
}
