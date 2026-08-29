import CoreText
import Foundation

/// Registers the bundled display font at launch so `Font.custom("Fraunces", …)` works
/// without an Info.plist entry.
enum AppFonts {
    static let display = "Fraunces"

    static func register() {
        for name in ["Fraunces", "Fraunces-Italic"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
