import SwiftUI

struct SplashView: View {
    @State private var shown = false

    // Always dark, regardless of the app's light/dark setting.
    private let ground = Color(red: 0.039, green: 0.047, blue: 0.043)   // #0A0C0B
    private let groundLow = Color(red: 0.055, green: 0.082, blue: 0.071) // #0E1512
    private let ink = Color(red: 0.973, green: 0.980, blue: 0.988)      // #F8FAFC
    private let inkSoft = Color(red: 0.580, green: 0.639, blue: 0.722)  // #94A3B8
    private let inkFaint = Color(red: 0.431, green: 0.475, blue: 0.522) // #6E7985

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [ground, groundLow], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                StorywickMark(animated: true)
                    .frame(width: 128, height: 128)
                    .glow(Theme.brandGreen, radius: 26)
                    .scaleEffect(shown ? 1 : 0.82)
                    .opacity(shown ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Storywick")
                        .font(.display(42, weight: .semibold, relativeTo: .largeTitle))
                        .foregroundStyle(ink)
                        .glow(Theme.brandGreen, radius: 12)

                    Text("Where stories find a voice")
                        .font(.callout)
                        .foregroundStyle(inkSoft)
                }
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 10)
            }

            VStack {
                Spacer()
                VStack(spacing: 3) {
                    Text("Powered By")
                        .font(.subheadline)
                        .foregroundStyle(inkFaint)
                    Text("Bikash")
                        .font(.display(24, weight: .medium, relativeTo: .title2))
                        .foregroundStyle(inkSoft)
                    Text(appVersion)
                        .font(.caption2)
                        .foregroundStyle(inkFaint)
                        .padding(.top, 6)
                }
                .opacity(shown ? 1 : 0)
                .padding(.bottom, 40)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { shown = true }
        }
    }
}

#Preview {
    SplashView()
}
