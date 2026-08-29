import Foundation
import SwiftData

/// DEBUG helper: seed one chapter so the reader and narration can be
/// exercised without typing. Only runs when launched with `-seedSample`.
enum SampleData {
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Story>())) ?? 0
        guard existing == 0 else { return }
        context.insert(Story(title: "The Lighthouse Keeper", text: chapter))
        try? context.save()
    }

    static let chapter = """
    The lamp had not gone out in forty years, and Aldous meant to keep it that way. \
    Every evening he climbed the ninety-seven steps, oiled the brass, and trimmed the wick \
    before the dark came rolling in off the water.

    That night the fog arrived early. It pressed against the glass like something alive, \
    swallowing the rocks, the jetty, and finally the sound of the sea itself. Aldous had \
    known the fog his whole life, but he had never known it to go so quiet.

    A bell rang once, far out in the white. Ships did not come this way anymore; the channel \
    had been closed since before his father's time. He waited, counting his own heartbeat, \
    and the bell rang again — closer now, and lower, as though it were sinking.

    He turned the light toward the sound. For an instant the beam caught something in the water: \
    tall, dark, and moving against the current. Then the fog closed over it, and the bell did \
    not ring a third time.

    Aldous stayed at the glass until morning. When the sun burned the last of the fog away, the \
    sea was empty and flat and ordinary, and the only thing on the rocks was a coil of rope \
    that no one on the island would admit to owning.
    """
}
