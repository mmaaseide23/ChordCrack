import SwiftUI

enum Achievement: String, Codable, CaseIterable {
    case firstSteps = "first_steps"
    case streakMaster = "streak_master"
    case perfectRound = "perfect_round"
    case barreExpert = "barre_expert"
    case bluesScholar = "blues_scholar"
    case powerPlayer = "power_player"
    case chordWizard = "chord_wizard"
    case perfectPitch = "perfect_pitch"
    case speedDemon = "speed_demon"

    var title: String {
        switch self {
        case .firstSteps: return "First Steps"
        case .streakMaster: return "Streak Master"
        case .perfectRound: return "Perfect Round"
        case .barreExpert: return "Barre Expert"
        case .bluesScholar: return "Blues Scholar"
        case .powerPlayer: return "Power Player"
        case .chordWizard: return "Chord Wizard"
        case .perfectPitch: return "Perfect Pitch"
        case .speedDemon: return "Speed Demon"
        }
    }

    var description: String {
        switch self {
        case .firstSteps: return "Play your first game"
        case .streakMaster: return "Achieve a 5+ streak"
        case .perfectRound: return "Perfect game (5/5)"
        case .barreExpert: return "80%+ barre chord accuracy"
        case .bluesScholar: return "70%+ blues chord accuracy"
        case .powerPlayer: return "90%+ power chord accuracy"
        case .chordWizard: return "Mixed mode mastery"
        case .perfectPitch: return "95%+ overall accuracy"
        case .speedDemon: return "High average scores"
        }
    }

    var icon: String {
        switch self {
        case .firstSteps: return "music.note"
        case .streakMaster: return "flame"
        case .perfectRound: return "star.circle.fill"
        case .barreExpert: return "guitars"
        case .bluesScholar: return "music.quarternote.3"
        case .powerPlayer: return "bolt"
        case .chordWizard: return "wand.and.stars"
        case .perfectPitch: return "ear"
        case .speedDemon: return "timer"
        }
    }

    var color: Color {
        switch self {
        case .firstSteps: return ColorTheme.primaryGreen
        case .streakMaster: return Color.orange
        case .perfectRound: return Color.yellow
        case .barreExpert: return Color.purple
        case .bluesScholar: return Color.blue
        case .powerPlayer: return Color.orange
        case .chordWizard: return Color.purple
        case .perfectPitch: return ColorTheme.lightGreen
        case .speedDemon: return Color.cyan
        }
    }
}
