import AVFoundation

struct KokoroVoiceOption: Identifiable, Hashable {
    let id: Int
    let name: String
    let gender: String
    let genderSymbol: String
    let accent: String
}

/// Speaker order for the bundled `kokoro-int8-en-v0_19` model (sid 0–10).
let kokoroVoiceOptions: [KokoroVoiceOption] = [
    .init(id: 0,  name: "Aria",     gender: "Female", genderSymbol: "person.wave.2.fill", accent: "American"),
    .init(id: 1,  name: "Bella",    gender: "Female", genderSymbol: "person.wave.2.fill", accent: "American"),
    .init(id: 2,  name: "Nicole",   gender: "Female", genderSymbol: "person.wave.2.fill", accent: "American"),
    .init(id: 3,  name: "Sarah",    gender: "Female", genderSymbol: "person.wave.2.fill", accent: "American"),
    .init(id: 4,  name: "Sky",      gender: "Female", genderSymbol: "person.wave.2.fill", accent: "American"),
    .init(id: 5,  name: "Adam",     gender: "Male",   genderSymbol: "person.wave.2",      accent: "American"),
    .init(id: 6,  name: "Michael",  gender: "Male",   genderSymbol: "person.wave.2",      accent: "American"),
    .init(id: 7,  name: "Emma",     gender: "Female", genderSymbol: "person.wave.2.fill", accent: "British"),
    .init(id: 8,  name: "Isabella", gender: "Female", genderSymbol: "person.wave.2.fill", accent: "British"),
    .init(id: 9,  name: "George",   gender: "Male",   genderSymbol: "person.wave.2",      accent: "British"),
    .init(id: 10, name: "Lewis",    gender: "Male",   genderSymbol: "person.wave.2",      accent: "British"),
]

struct VoiceOption: Identifiable, Hashable {
    let id: String        // AVSpeechSynthesisVoice.identifier
    let name: String
    let accent: String    // "British", "American", …
    let gender: String    // "Male", "Female", "Siri", "Voice"
    let genderSymbol: String
    let quality: String?  // "Enhanced", "Premium", "Personal Voice", or nil
    let sortKey: Int      // lower = show first
}

enum VoiceCatalog {
    /// English voices worth narrating with — Siri, enhanced and premium voices,
    /// and the standard gendered system voices. Apple's novelty voices
    /// (Bells, Boing, Bubbles, …) are left out.
    static func voices() -> [VoiceOption] {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        let narration = english.filter(isNarrationVoice)
        let source = narration.isEmpty ? english : narration

        return source
            .map(option(from:))
            .sorted {
                if $0.sortKey != $1.sortKey { return $0.sortKey < $1.sortKey }
                if $0.accent != $1.accent { return $0.accent < $1.accent }
                return $0.name < $1.name
            }
    }

    private static func isNarrationVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if voice.identifier.contains(".siri") { return true }
        if voice.voiceTraits.contains(.isPersonalVoice) { return true }
        if voice.quality == .enhanced || voice.quality == .premium { return true }
        return voice.gender == .male || voice.gender == .female
    }

    private static func option(from voice: AVSpeechSynthesisVoice) -> VoiceOption {
        let (label, symbol) = descriptor(for: voice)
        return VoiceOption(
            id: voice.identifier,
            name: displayName(for: voice),
            accent: accent(for: voice.language),
            gender: label,
            genderSymbol: symbol,
            quality: qualityLabel(for: voice),
            sortKey: sortKey(for: voice)
        )
    }

    private static func descriptor(for voice: AVSpeechSynthesisVoice) -> (String, String) {
        if voice.voiceTraits.contains(.isPersonalVoice) { return ("Personal", "person.crop.circle") }
        if voice.identifier.contains(".siri") { return ("Siri", "sparkles") }
        switch voice.gender {
        case .male: return ("Male", "person.wave.2")
        case .female: return ("Female", "person.wave.2.fill")
        default: return ("Voice", "waveform")
        }
    }

    private static func displayName(for voice: AVSpeechSynthesisVoice) -> String {
        if voice.identifier.contains(".siri") {
            // Siri voice names arrive like "Nicky (Enhanced)" or "Voice 4"
            return voice.name
                .replacingOccurrences(of: " (Enhanced)", with: "")
                .replacingOccurrences(of: " (Premium)", with: "")
        }
        return voice.name
    }

    private static func qualityLabel(for voice: AVSpeechSynthesisVoice) -> String? {
        if voice.voiceTraits.contains(.isPersonalVoice) { return "Personal Voice" }
        switch voice.quality {
        case .enhanced: return "Enhanced"
        case .premium: return "Premium"
        default: return nil
        }
    }

    private static func sortKey(for voice: AVSpeechSynthesisVoice) -> Int {
        if voice.voiceTraits.contains(.isPersonalVoice) { return 0 }
        if voice.identifier.contains(".siri") { return 1 }
        if voice.quality == .premium { return 2 }
        if voice.quality == .enhanced { return 3 }
        return 4
    }

    private static func accent(for language: String) -> String {
        switch language.lowercased() {
        case "en-us": return "American"
        case "en-gb": return "British"
        case "en-au": return "Australian"
        case "en-ie": return "Irish"
        case "en-za": return "South African"
        case "en-in": return "Indian"
        case "en-nz": return "New Zealand"
        case "en-ca": return "Canadian"
        default:
            return Locale.current.localizedString(forIdentifier: language) ?? language
        }
    }
}
