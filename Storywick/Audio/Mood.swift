import Foundation

/// Background mood for a chapter. Each mood maps to one bundled music bed
/// (Kevin MacLeod, CC-BY 4.0) — several names share a bed.
enum Mood: String, CaseIterable, Identifiable {
    case none
    case thriller, suspense, horror, mystery, fantasy, adventure, comedy, romance
    case sad, inspirational, calm, dramatic, epic, magical, darkEerie, sciFi
    case action, nostalgic, dreamy, whimsical, feelGood, melancholic
    case atmospheric, cinematic, meditative

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .thriller: return "Thriller"
        case .suspense: return "Suspense"
        case .horror: return "Horror"
        case .mystery: return "Mystery"
        case .fantasy: return "Fantasy"
        case .adventure: return "Adventure"
        case .comedy: return "Comedy"
        case .romance: return "Romance"
        case .sad: return "Emotional / Sad"
        case .inspirational: return "Inspirational"
        case .calm: return "Peaceful / Calm"
        case .dramatic: return "Dramatic"
        case .epic: return "Epic"
        case .magical: return "Magical / Enchanted"
        case .darkEerie: return "Dark / Eerie"
        case .sciFi: return "Sci-Fi / Futuristic"
        case .action: return "Action"
        case .nostalgic: return "Nostalgic"
        case .dreamy: return "Dreamy"
        case .whimsical: return "Whimsical / Playful"
        case .feelGood: return "Feel-Good / Happy"
        case .melancholic: return "Melancholic"
        case .atmospheric: return "Mysterious / Atmospheric"
        case .cinematic: return "Cinematic"
        case .meditative: return "Meditative / Ambient"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "speaker.slash"
        case .thriller, .action: return "bolt.fill"
        case .suspense: return "eye.trianglebadge.exclamationmark"
        case .horror, .darkEerie: return "theatermasks.fill"
        case .mystery, .atmospheric: return "magnifyingglass"
        case .fantasy, .magical: return "wand.and.stars"
        case .adventure: return "map.fill"
        case .comedy, .whimsical, .feelGood: return "face.smiling"
        case .romance: return "heart.fill"
        case .sad, .melancholic: return "cloud.rain.fill"
        case .inspirational: return "sun.max.fill"
        case .calm, .meditative: return "leaf.fill"
        case .dramatic, .cinematic: return "film.fill"
        case .epic: return "mountain.2.fill"
        case .sciFi: return "atom"
        case .nostalgic, .dreamy: return "moon.stars.fill"
        }
    }

    /// Bundled music bed (basename in `MoodMusic/`). Several moods share one.
    var track: String? {
        switch self {
        case .none: return nil
        case .calm: return "calm"
        case .meditative: return "meditative"
        case .sad, .melancholic: return "sad"
        case .romance: return "romance"
        case .dreamy, .nostalgic: return "dreamy"
        case .mystery, .atmospheric, .cinematic: return "mystery"
        case .suspense: return "suspense"
        case .thriller, .action: return "thriller"
        case .horror, .darkEerie: return "horror"
        case .epic, .adventure, .dramatic: return "epic"
        case .inspirational: return "inspirational"
        case .fantasy, .magical: return "fantasy"
        case .sciFi: return "scifi"
        case .comedy, .whimsical, .feelGood: return "comedy"
        }
    }
}
