import SwiftUI

/// Shows the branded splash briefly, then the app. Also the single owner of the
/// window colour scheme: the app theme normally, forced dark only while the
/// always-dark splash is up so the status bar matches it.
struct RootView: View {
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue
    @State private var showSplash = true

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .dark }
    private var scheme: ColorScheme { showSplash ? .dark : appearance.colorScheme }

    var body: some View {
        ZStack {
            HomeView()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(scheme)
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
        }
    }
}
