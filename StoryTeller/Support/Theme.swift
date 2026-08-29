import SwiftUI
import UIKit

// MARK: - Appearance

enum AppAppearance: String, CaseIterable, Identifiable {
    case light, dark

    var id: String { rawValue }
    var label: String { self == .light ? "Light" : "Dark" }
    var symbol: String { self == .light ? "sun.max.fill" : "moon.stars.fill" }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
    var toggled: AppAppearance { self == .light ? .dark : .light }
}

// MARK: - Palette

enum Theme {
    static let display = AppFonts.display

    private static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // "Emerald" in both themes — clean mint + emerald in light, near-black + emerald glow in dark.
    static var background: Color        { adaptive(light: 0xF6F9F7, dark: 0x0A0C0B) }
    static var backgroundLow: Color     { adaptive(light: 0xEDF3EF, dark: 0x0E1512) }
    static var surface: Color           { adaptive(light: 0xFFFFFF, dark: 0x141A18) }
    static var surfaceRaised: Color     { adaptive(light: 0xFFFFFF, dark: 0x1B231F) }
    static var stroke: Color            { adaptive(light: 0xE2E8E5, dark: 0x1F2937) }
    static var textPrimary: Color       { adaptive(light: 0x111827, dark: 0xF8FAFC) }
    static var textSecondary: Color     { adaptive(light: 0x64748B, dark: 0x94A3B8) }
    static var textFaint: Color         { adaptive(light: 0x94A3B8, dark: 0x5A6B7A) }
    static var accent: Color            { adaptive(light: 0x059669, dark: 0x10B981) }
    static var accentDeep: Color        { adaptive(light: 0x047857, dark: 0x059669) }
    static var accentSoft: Color        { adaptive(light: 0xE4F3EC, dark: 0x0E2A22) }
    static var glow: Color              { adaptive(light: 0x34D399, dark: 0x34D399) }
    static var spark: Color             { adaptive(light: 0x65A30D, dark: 0xA3E635) }
    static var highlight: Color         { adaptive(light: 0xC7ECDA, dark: 0x123329) }
    static var warning: Color           { adaptive(light: 0xD97706, dark: 0xF59E0B) }
    static var danger: Color            { adaptive(light: 0xDC2626, dark: 0xF87171) }
}

extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Fonts

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(Theme.display, size: size, relativeTo: textStyle).weight(weight)
    }
}

// MARK: - Effects

extension View {
    /// Soft two-pass glow. Pass `active: false` to keep layout stable but hide it.
    func glow(_ color: Color = Theme.glow, radius: CGFloat = 12, active: Bool = true) -> some View {
        self
            .shadow(color: active ? color.opacity(0.55) : .clear, radius: radius)
            .shadow(color: active ? color.opacity(0.28) : .clear, radius: radius * 2.2)
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.background, Theme.backgroundLow],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
