import SwiftUI

enum GameType {
    case dailyChallenge
    case basicPractice
    case barrePractice
    case bluesPractice
    case powerPractice
    case mixedPractice
    case extendedPractice
    case chordProgression
    case speedRound

    var displayName: String {
        switch self {
        case .dailyChallenge: return "Daily Challenge"
        case .basicPractice: return "Basic Practice"
        case .barrePractice: return "Barre Practice"
        case .bluesPractice: return "Blues Practice"
        case .powerPractice: return "Power Practice"
        case .mixedPractice: return "Mixed Practice"
        case .extendedPractice: return "Extended Practice"
        case .chordProgression: return "Chord Progressions"
        case .speedRound: return "Speed Round"
        }
    }

    var color: Color {
        switch self {
        case .dailyChallenge: return ColorTheme.primaryGreen
        case .basicPractice: return ColorTheme.primaryGreen
        case .barrePractice: return ColorTheme.barre
        case .bluesPractice: return ColorTheme.blues
        case .powerPractice: return ColorTheme.power
        case .mixedPractice: return ColorTheme.mixed
        case .extendedPractice: return ColorTheme.extended
        case .chordProgression: return ColorTheme.progression
        case .speedRound: return ColorTheme.power
        }
    }
}
