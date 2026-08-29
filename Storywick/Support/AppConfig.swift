import Foundation

enum AppConfig {
    /// Maximum words in a single pasted chapter.
    static let wordLimit = 5_000

    /// How many past chapters to keep. The oldest is dropped when a new one
    /// pushes past this. Change this one number to keep more or fewer.
    static let historyLimit = 10
}
