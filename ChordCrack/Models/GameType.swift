import SwiftUI

enum GameType {
    case dailyChallenge
    case basicPractice
    case barrePractice
    case bluesPractice
    case powerPractice
    case mixedPractice
    case speedRound

    var displayName: String {
        switch self {
        case .dailyChallenge: return "Daily Challenge"
        case .basicPractice: return "Basic Practice"
        case .barrePractice: return "Barre Practice"
        case .bluesPractice: return "Blues Practice"
        case .powerPractice: return "Power Practice"
        case .mixedPractice: return "Mixed Practice"
        case .speedRound: return "Speed Round"
        }
    }

    var color: Color {
        switch self {
        case .dailyChallenge: return ColorTheme.primaryGreen
        case .basicPractice: return ColorTheme.primaryGreen
        case .barrePractice: return Color.orange
        case .bluesPractice: return Color.blue
        case .powerPractice: return Color.red
        case .mixedPractice: return Color.purple
        case .speedRound: return Color.red
        }
    }
}
