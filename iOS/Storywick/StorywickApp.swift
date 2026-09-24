import SwiftUI
import SwiftData

@main
struct StorywickApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var narrator = Narrator()
    private let container: ModelContainer

    init() {
        AppFonts.register()
        do {
            container = try ModelContainer(for: Story.self)
        } catch {
            fatalError("Could not create the model container: \(error)")
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSample") {
            SampleData.seedIfNeeded(container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(narrator)
                .tint(Theme.accent)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            // Flush the reading position to disk before the app can be
            // suspended or killed in the background.
            if phase != .active {
                narrator.persistNow()
                try? container.mainContext.save()
            }
        }
    }
}
