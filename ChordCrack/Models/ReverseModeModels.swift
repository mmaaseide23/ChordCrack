import Foundation
import SwiftUI

// MARK: - Reverse Mode Specific Models

/// Represents a finger position on the fretboard
struct FingerPosition: Hashable, Codable {
    let string: Int  // 0-5 (E4 to E2)
    let fret: Int    // 0-12
    
    /// Converts to string name for audio file lookup
    var stringName: String {
        switch string {
        case 0: return "E4"
        case 1: return "B4"
        case 2: return "G3"
        case 3: return "D3"
        case 4: return "A3"
        case 5: return "E2"
        default: return "E2"
        }
    }
}

/// Reverse mode game session
struct ReverseModeSession: Codable {
    let id: UUID
    let username: String
    let score: Int
    let streak: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let gameType: String
    let hintsUsed: Int
    let soundHintsUsed: Int
    let theoryHintsUsed: Int
    let createdAt: Date
    
    init(username: String, score: Int, streak: Int, correctAnswers: Int,
         totalQuestions: Int, gameType: String, hintsUsed: Int = 0,
         soundHintsUsed: Int = 0, theoryHintsUsed: Int = 0) {
        self.id = UUID()
        self.username = username
        self.score = score
        self.streak = streak
        self.correctAnswers = correctAnswers
        self.totalQuestions = totalQuestions
        self.gameType = gameType
        self.hintsUsed = hintsUsed
        self.soundHintsUsed = soundHintsUsed
        self.theoryHintsUsed = theoryHintsUsed
        self.createdAt = Date()
    }
}

/// User preferences including reverse mode toggle
struct UserPreferences: Codable {
    var reverseModeEnabled: Bool
    var preferredTheme: String
    var soundEffectsEnabled: Bool
    var hapticFeedbackEnabled: Bool
    
    static let `default` = UserPreferences(
        reverseModeEnabled: false,
        preferredTheme: "green",
        soundEffectsEnabled: true,
        hapticFeedbackEnabled: true
    )
}

// MARK: - Reverse Mode Database Response Models

struct ReverseModeStatsDBResponse: Codable {
    let id: String
    let username: String
    let totalGames: Int
    let bestScore: Int
    let bestStreak: Int
    let averageScore: Double
    let totalCorrect: Int
    let totalQuestions: Int
    let powerChordAccuracy: Double
    let barreChordAccuracy: Double
    let bluesChordAccuracy: Double
    let basicChordAccuracy: Double
    let totalXp: Int
    let currentLevel: Int
    
    enum CodingKeys: String, CodingKey {
        case id, username
        case totalGames = "total_games"
        case bestScore = "best_score"
        case bestStreak = "best_streak"
        case averageScore = "average_score"
        case totalCorrect = "total_correct"
        case totalQuestions = "total_questions"
        case powerChordAccuracy = "power_chord_accuracy"
        case barreChordAccuracy = "barre_chord_accuracy"
        case bluesChordAccuracy = "blues_chord_accuracy"
        case basicChordAccuracy = "basic_chord_accuracy"
        case totalXp = "total_xp"
        case currentLevel = "current_level"
    }
}

struct ReverseModeSessionDBResponse: Codable {
    let id: Int
    let userId: String
    let username: String
    let score: Int
    let streak: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let gameType: String
    let hintsUsed: Int
    let soundHintsUsed: Int
    let theoryHintsUsed: Int
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username, score, streak
        case correctAnswers = "correct_answers"
        case totalQuestions = "total_questions"
        case gameType = "game_type"
        case hintsUsed = "hints_used"
        case soundHintsUsed = "sound_hints_used"
        case theoryHintsUsed = "theory_hints_used"
        case createdAt = "created_at"
    }
}

struct UserPreferencesDBResponse: Codable {
    let userId: String
    let reverseModeEnabled: Bool
    let preferredTheme: String
    let soundEffectsEnabled: Bool
    let hapticFeedbackEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case reverseModeEnabled = "reverse_mode_enabled"
        case preferredTheme = "preferred_theme"
        case soundEffectsEnabled = "sound_effects_enabled"
        case hapticFeedbackEnabled = "haptic_feedback_enabled"
    }
}

struct ReverseModeLeaderboardEntry: Codable, Identifiable {
    var id: String { username }
    let rank: Int
    let username: String
    let bestScore: Int
    let totalGames: Int
    let currentLevel: Int
    let totalXp: Int
}


// MARK: - Reverse Mode Achievement Enum

enum ReverseModeAchievement: String, Codable, CaseIterable {
    case reverseFirstSteps = "reverse_first_steps"
    case reverseStreakMaster = "reverse_streak_master"
    case reversePerfectRound = "reverse_perfect_round"
    case reverseNoHints = "reverse_no_hints"
    case reverseSpeedDemon = "reverse_speed_demon"
    case reverseChordBuilder = "reverse_chord_builder"
    case reverseTheoryMaster = "reverse_theory_master"
    case reverseAccuracyAce = "reverse_accuracy_ace"
    case reverseLevel10 = "reverse_level_10"
    case reverseLevel25 = "reverse_level_25"
    
    var title: String {
        switch self {
        case .reverseFirstSteps: return "Reverse First Steps"
        case .reverseStreakMaster: return "Reverse Streak Master"
        case .reversePerfectRound: return "Perfect Builder"
        case .reverseNoHints: return "No Hints Needed"
        case .reverseSpeedDemon: return "Speed Builder"
        case .reverseChordBuilder: return "Chord Architect"
        case .reverseTheoryMaster: return "Theory Expert"
        case .reverseAccuracyAce: return "Accuracy Master"
        case .reverseLevel10: return "Level 10 Builder"
        case .reverseLevel25: return "Level 25 Builder"
        }
    }
    
    var description: String {
        switch self {
        case .reverseFirstSteps: return "Complete your first reverse mode game"
        case .reverseStreakMaster: return "Achieve a 5+ streak in reverse mode"
        case .reversePerfectRound: return "Perfect reverse mode game"
        case .reverseNoHints: return "Complete without using hints"
        case .reverseSpeedDemon: return "Fast chord building"
        case .reverseChordBuilder: return "Build 100 chords correctly"
        case .reverseTheoryMaster: return "Master chord theory"
        case .reverseAccuracyAce: return "95%+ reverse mode accuracy"
        case .reverseLevel10: return "Reach level 10 in reverse mode"
        case .reverseLevel25: return "Reach level 25 in reverse mode"
        }
    }
    
    var icon: String {
        switch self {
        case .reverseFirstSteps: return "hand.point.up.fill"
        case .reverseStreakMaster: return "flame.fill"
        case .reversePerfectRound: return "star.circle.fill"
        case .reverseNoHints: return "eye.slash.fill"
        case .reverseSpeedDemon: return "bolt.fill"
        case .reverseChordBuilder: return "hammer.fill"
        case .reverseTheoryMaster: return "book.fill"
        case .reverseAccuracyAce: return "target"
        case .reverseLevel10: return "10.circle.fill"
        case .reverseLevel25: return "25.circle.fill"
        }
    }
    
    var color: Color {
        return ColorTheme.primaryPurple
    }
}
