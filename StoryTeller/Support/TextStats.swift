import Foundation

enum TextStats {
    /// Locale-aware word count.
    static func wordCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .localized]) { _, _, _, _ in
            count += 1
        }
        return count
    }

    /// Split into trimmed sentences for narration, progress, and highlighting.
    static func sentences(_ text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .localized]) { substring, _, _, _ in
            let trimmed = substring?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { return }
            result.append(trimmed)
        }
        if result.isEmpty, !text.isEmpty {
            result = [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        return result
    }
}
