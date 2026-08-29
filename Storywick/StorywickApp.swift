import SwiftUI
import SwiftData

@main
struct StorywickApp: App {
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
    }
}
