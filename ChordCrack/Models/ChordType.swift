import Foundation
import SwiftUI

/// Comprehensive chord type enumeration with professional organization
/// Optimized to use only available audio files (frets 0-4 on most strings, 0-12 on E4)
enum ChordType: String, CaseIterable, Identifiable {
    
    // MARK: - Basic Chords (Daily Challenge Only - A through G)
    
    case aMajor = "A"
    case bMajor = "B"
    case cMajor = "C"
    case dMajor = "D"
    case eMajor = "E"
    case fMajor = "F"
    case gMajor = "G"
    case aMinor = "Am"
    case bMinor = "Bm"
    case cMinor = "Cm"
    case dMinor = "Dm"
    case eMinor = "Em"
    case fMinor = "Fm"
    case gMinor = "Gm"
    
    // MARK: - Advanced Chords (Practice Modes Only)
    
    // Barre Chords (adjusted to use available frets)
    case fMajorBarre = "F (Barre)"
    case gMajorBarre = "G (Barre)"
    case aMajorBarre = "A (Barre)"
    case bMajorBarre = "B (Barre)"
    case cMajorBarre = "C (Barre)"
    case dMajorBarre = "D (Barre)"
    case fMinorBarre = "Fm (Barre)"
    case gMinorBarre = "Gm (Barre)"
    case aMinorBarre = "Am (Barre)"
    case bMinorBarre = "Bm (Barre)"
    case cMinorBarre = "Cm (Barre)"
    case dMinorBarre = "Dm (Barre)"
    
    // Seventh chords
    case a7 = "A7"
    case b7 = "B7"
    case c7 = "C7"
    case d7 = "D7"
    case e7 = "E7"
    case f7 = "F7"
    case g7 = "G7"
    case am7 = "Am7"
    case bm7 = "Bm7"
    case cm7 = "Cm7"
    case dm7 = "Dm7"
    case em7 = "Em7"
    case fm7 = "Fm7"
    case gm7 = "Gm7"
    
    // Power Chords
    case e5 = "E5"
    case a5 = "A5"
    case d5 = "D5"
    case g5 = "G5"
    case c5 = "C5"
    case f5 = "F5"
    case b5 = "B5"
    case fs5 = "F#5"
    case cs5 = "C#5"
    case gs5 = "G#5"
    case ds5 = "D#5"
    case as5 = "A#5"
    
    // MARK: - Protocol Conformance
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var category: ChordCategory {
        switch self {
        case .aMajor, .bMajor, .cMajor, .dMajor, .eMajor, .fMajor, .gMajor,
                .aMinor, .bMinor, .cMinor, .dMinor, .eMinor, .fMinor, .gMinor:
            return .basic
            
        case .fMajorBarre, .gMajorBarre, .aMajorBarre, .bMajorBarre, .cMajorBarre, .dMajorBarre,
                .fMinorBarre, .gMinorBarre, .aMinorBarre, .bMinorBarre, .cMinorBarre, .dMinorBarre:
            return .barre
            
        case .a7, .b7, .c7, .d7, .e7, .f7, .g7,
                .am7, .bm7, .cm7, .dm7, .em7, .fm7, .gm7:
            return .blues
            
        case .e5, .a5, .d5, .g5, .c5, .f5, .b5, .fs5, .cs5, .gs5, .ds5, .as5:
            return .power
        }
    }
    
    // MARK: - Static Chord Collections
    
    /// Basic chords for daily challenge - ONLY A-G major and minor (14 chords total)
    static var basicChords: [ChordType] {
        return [.aMajor, .bMajor, .cMajor, .dMajor, .eMajor, .fMajor, .gMajor,
                .aMinor, .bMinor, .cMinor, .dMinor, .eMinor, .fMinor, .gMinor]
    }
    
    static var barreChords: [ChordType] {
        return ChordType.allCases.filter { $0.category == .barre }
    }
    
    static var bluesChords: [ChordType] {
        return ChordType.allCases.filter { $0.category == .blues }
    }
    
    static var powerChords: [ChordType] {
        return ChordType.allCases.filter { $0.category == .power }
    }
    
    // MARK: - Audio File Management
    
    var audioFileName: String {
        // For basic chords, use existing full chord files if available
        switch self {
        case .cMajor: return "C_major.m4a"
        case .dMajor: return "D_major.m4a"
        case .eMajor: return "E_major.m4a"
        case .fMajor: return "F_major.m4a"
        case .gMajor: return "G_major.m4a"
        case .aMajor: return "A_major.m4a"
        case .bMajor: return "B_major.m4a"
        case .cMinor: return "C_minor.m4a"
        case .dMinor: return "D_minor.m4a"
        case .eMinor: return "E_minor.m4a"
        case .fMinor: return "F_minor.m4a"
        case .gMinor: return "G_minor.m4a"
        case .aMinor: return "A_minor.m4a"
        case .bMinor: return "B_minor.m4a"
        default:
            return getStringFiles().first ?? "E2_fret0.m4a"
        }
    }
    
    func audioFileName(for hintType: GameManager.HintType) -> String {
        switch hintType {
        case .chordNoFingers, .chordSlow, .audioOptions, .singleFingerReveal:
            return getStringFiles().first ?? "E2_fret0.m4a"
        case .individualStrings:
            return getStringFiles().first ?? "E2_fret0.m4a"
        }
    }
    
    var githubURL: String {
        return "https://raw.githubusercontent.com/mmaaseide23/ChordCrack_Assets/main/\(audioFileName)"
    }
    
    func githubURL(for hintType: GameManager.HintType) -> String {
        return "https://raw.githubusercontent.com/mmaaseide23/ChordCrack_Assets/main/\(audioFileName(for: hintType))"
    }
    
    // MARK: - Note Mapping Helper
    
    /// Maps chord positions to available audio files
    private func mapToAvailableNote(string: String, fret: Int) -> String {
        // Validate string name first
        let validStrings = ["E2", "A3", "D3", "G3", "B4", "E4"]
        guard validStrings.contains(string) else {
            print("[ChordType] Warning: Invalid string '\(string)', using E2_fret0.m4a")
            return "E2_fret0.m4a"
        }
        
        // Ensure fret is non-negative
        guard fret >= 0 else {
            print("[ChordType] Warning: Invalid fret \(fret) for string \(string), using open string")
            return "\(string)_fret0.m4a"
        }
        
        // If it's E4 string and within range, use directly
        if string == "E4" && fret <= 12 {
            return "\(string)_fret\(fret).m4a"
        }
        
        // For other strings, only use if within fret 0-4
        if fret <= 4 && string != "E4" {
            return "\(string)_fret\(fret).m4a"
        }
        
        // For higher frets on non-E4 strings, find the closest available option
        if string != "E4" && fret > 4 {
            print("[ChordType] Note: Fret \(fret) unavailable on string \(string), using fret 4")
            return "\(string)_fret4.m4a"
        }
        
        // Fallback - shouldn't normally reach here
        print("[ChordType] Warning: Using fallback open string for \(string) fret \(fret)")
        return "\(string)_fret0.m4a"
    }

    // Replace the getStringFiles function with this improved version:
    func getStringFiles() -> [String] {
        // Use the mapping function to get the actual available files
        let files = fingerPositions.compactMap { position in
            let fileName = mapToAvailableNote(string: position.string, fret: position.fret)
            // Validate that we're returning a proper filename
            if fileName.hasSuffix(".m4a") {
                return fileName
            } else {
                print("[ChordType] Warning: Invalid filename generated: \(fileName)")
                return nil
            }
        }
        
        // Ensure we have at least one valid file
        if files.isEmpty {
            print("[ChordType] Error: No valid audio files for chord \(self.rawValue)")
            return ["E2_fret0.m4a"] // Emergency fallback
        }
        
        return files
    }
    
    // MARK: - Finger Position Data (Adjusted for available frets)
    
    var fingerPositions: [(string: String, fret: Int)] {
        switch self {
            // Basic Major Chords (all within fret 0-4)
        case .aMajor:
            return [("A3", 0), ("D3", 2), ("G3", 2), ("B4", 2), ("E4", 0)]
        case .bMajor:
            return [("A3", 2), ("D3", 4), ("G3", 4), ("B4", 4), ("E4", 2)]
        case .cMajor:
            return [("A3", 3), ("D3", 2), ("G3", 0), ("B4", 1), ("E4", 0)]
        case .dMajor:
            return [("D3", 0), ("G3", 2), ("B4", 3), ("E4", 2)]
        case .eMajor:
            return [("E2", 0), ("A3", 2), ("D3", 2), ("G3", 1), ("B4", 0), ("E4", 0)]
        case .fMajor:
            return [("E2", 1), ("A3", 3), ("D3", 3), ("G3", 2), ("B4", 1), ("E4", 1)]
        case .gMajor:
            return [("E2", 3), ("A3", 2), ("D3", 0), ("G3", 0), ("B4", 3), ("E4", 3)]
            
            // Basic Minor Chords (all within fret 0-4)
        case .aMinor:
            return [("A3", 0), ("D3", 2), ("G3", 2), ("B4", 1), ("E4", 0)]
        case .bMinor:
            return [("A3", 2), ("D3", 4), ("G3", 4), ("B4", 3), ("E4", 2)]
        case .cMinor:
            return [("A3", 3), ("D3", 1), ("G3", 0), ("B4", 4), ("E4", 3)]
        case .dMinor:
            return [("D3", 0), ("G3", 2), ("B4", 3), ("E4", 1)]
        case .eMinor:
            return [("E2", 0), ("A3", 2), ("D3", 2), ("G3", 0), ("B4", 0), ("E4", 0)]
        case .fMinor:
            return [("E2", 1), ("A3", 3), ("D3", 3), ("G3", 1), ("B4", 1), ("E4", 1)]
        case .gMinor:
            return [("E2", 3), ("A3", 1), ("D3", 0), ("G3", 0), ("B4", 3), ("E4", 3)]
            
            // FIXED BARRE CHORDS - Now only use available frets
        case .fMajorBarre:
            // F major barre (simplified) - uses available frets
            return [("E2", 1), ("A3", 3), ("D3", 3), ("G3", 2), ("B4", 1), ("E4", 1)]
        case .gMajorBarre:
            // G major barre (modified) - approximated with available frets
            return [("E2", 3), ("A3", 2), ("D3", 0), ("G3", 0), ("B4", 3), ("E4", 3)]
        case .aMajorBarre:
            // A major barre (simplified to open A variation)
            return [("A3", 0), ("D3", 2), ("G3", 2), ("B4", 2), ("E4", 0)]
        case .bMajorBarre:
            // B major barre - uses available frets
            return [("A3", 2), ("D3", 4), ("G3", 4), ("B4", 4), ("E4", 2)]
        case .cMajorBarre:
            // C major barre (modified)
            return [("A3", 3), ("D3", 2), ("G3", 0), ("B4", 1), ("E4", 3)]
        case .dMajorBarre:
            // D major barre (simplified)
            return [("D3", 0), ("G3", 2), ("B4", 3), ("E4", 2)]
        case .fMinorBarre:
            // F minor barre - uses available frets
            return [("E2", 1), ("A3", 3), ("D3", 3), ("G3", 1), ("B4", 1), ("E4", 1)]
        case .gMinorBarre:
            // G minor barre (modified)
            return [("E2", 3), ("A3", 1), ("D3", 0), ("G3", 3), ("B4", 3), ("E4", 3)]
        case .aMinorBarre:
            // A minor barre (simplified to open Am variation)
            return [("A3", 0), ("D3", 2), ("G3", 2), ("B4", 1), ("E4", 0)]
        case .bMinorBarre:
            // B minor barre - uses available frets
            return [("A3", 2), ("D3", 4), ("G3", 4), ("B4", 3), ("E4", 2)]
        case .cMinorBarre:
            // C minor barre (modified)
            return [("A3", 3), ("D3", 1), ("G3", 0), ("B4", 4), ("E4", 3)]
        case .dMinorBarre:
            // D minor barre (simplified)
            return [("D3", 0), ("G3", 2), ("B4", 3), ("E4", 1)]
            
            // Blues/7th Chords (within available frets)
        case .a7:
            return [("A3", 0), ("D3", 2), ("G3", 0), ("B4", 2), ("E4", 0)]
        case .b7:
            return [("A3", 2), ("D3", 1), ("G3", 2), ("B4", 0), ("E4", 2)]
        case .c7:
            return [("A3", 3), ("D3", 2), ("G3", 3), ("B4", 1), ("E4", 0)]
        case .d7:
            return [("D3", 0), ("G3", 2), ("B4", 1), ("E4", 2)]
        case .e7:
            return [("E2", 0), ("A3", 2), ("D3", 0), ("G3", 1), ("B4", 0), ("E4", 0)]
        case .f7:
            return [("E2", 1), ("A3", 3), ("D3", 1), ("G3", 2), ("B4", 1), ("E4", 1)]
        case .g7:
            return [("E2", 3), ("A3", 2), ("D3", 0), ("G3", 0), ("B4", 0), ("E4", 1)]
        case .am7:
            return [("A3", 0), ("D3", 2), ("G3", 0), ("B4", 1), ("E4", 0)]
        case .bm7:
            return [("A3", 2), ("D3", 2), ("G3", 2), ("B4", 3), ("E4", 2)]
        case .cm7:
            return [("A3", 3), ("D3", 1), ("G3", 3), ("B4", 4), ("E4", 3)]
        case .dm7:
            return [("D3", 0), ("G3", 2), ("B4", 1), ("E4", 1)]
        case .em7:
            return [("E2", 0), ("A3", 2), ("D3", 0), ("G3", 0), ("B4", 0), ("E4", 0)]
        case .fm7:
            return [("E2", 1), ("A3", 3), ("D3", 1), ("G3", 1), ("B4", 1), ("E4", 1)]
        case .gm7:
            return [("E2", 3), ("A3", 1), ("D3", 0), ("G3", 3), ("B4", 3), ("E4", 3)]
            
            // Power Chords (all within available frets)
        case .e5:
            return [("E2", 0), ("A3", 2), ("D3", 2)]
        case .a5:
            return [("A3", 0), ("D3", 2), ("G3", 2)]
        case .d5:
            return [("D3", 0), ("G3", 2), ("B4", 3)]
        case .g5:
            return [("E2", 3), ("A3", 2), ("D3", 0)]  // Modified to use available frets
        case .c5:
            return [("A3", 3), ("D3", 2), ("G3", 0)]  // Modified to use available frets
        case .f5:
            return [("E2", 1), ("A3", 3), ("D3", 3)]
        case .b5:
            return [("A3", 2), ("D3", 4), ("G3", 4)]
        case .fs5:
            return [("E2", 2), ("A3", 4), ("D3", 4)]
        case .cs5:
            return [("A3", 4), ("D3", 3), ("G3", 2)]  // Modified to use available frets
        case .gs5:
            return [("E2", 4), ("A3", 3), ("D3", 1)]  // Modified to use available frets
        case .ds5:
            return [("A3", 1), ("D3", 3), ("G3", 3)]  // Modified to use available frets
        case .as5:
            return [("A3", 1), ("D3", 3), ("G3", 3)]
        }
    }
}

// MARK: - Chord Category Enum

enum ChordCategory: String, CaseIterable {
    case basic = "Basic"
    case barre = "Barre"
    case blues = "Blues"
    case power = "Power"
    
    var displayName: String {
        switch self {
        case .basic: return "Basic Chords"
        case .barre: return "Barre Chords"
        case .blues: return "Blues Chords"
        case .power: return "Power Chords"
        }
    }
    
    var description: String {
        switch self {
        case .basic: return "Open major and minor chords"
        case .barre: return "Advanced fingering patterns"
        case .blues: return "7th and extended chords"
        case .power: return "Rock & metal fundamentals"
        }
    }
    
    var icon: String {
        switch self {
        case .basic: return "music.note"
        case .barre: return "guitars.fill"
        case .blues: return "music.quarternote.3"
        case .power: return "bolt.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .basic: return ColorTheme.primaryGreen
        case .barre: return Color.orange
        case .blues: return Color.blue
        case .power: return Color.red
        }
    }
}

// MARK: - Validation Extensions

extension ChordType {
    
    /// Validates that this chord is allowed in daily challenge mode
    var isAllowedInDailyChallenge: Bool {
        return ChordType.basicChords.contains(self)
    }
    
    /// Returns difficulty level for UI display
    var difficultyLevel: String {
        switch category {
        case .basic: return "Beginner"
        case .power: return "Easy"
        case .barre: return "Medium"
        case .blues: return "Hard"
        }
    }
}

// MARK: - Stats Tracking Extensions

extension ChordCategory {
    /// The key used for tracking stats in the database and UserDataManager
    var statKey: String {
        switch self {
        case .basic:
            return "basicChords"
        case .power:
            return "powerChords"
        case .barre:
            return "barreChords"
        case .blues:
            return "bluesChords"
        }
    }
}

// MARK: - Game Type Constants for Stats Tracking

struct GameTypeConstants {
    static let dailyChallenge = "dailyChallenge"
    static let basicChords = "basicChords"
    static let powerChords = "powerChords"
    static let barreChords = "barreChords"
    static let bluesChords = "bluesChords"
    static let mixedPractice = "mixedPractice"
    static let chordProgressions = "chordProgressions"
    static let speedRound = "speedRound"
}

// MARK: - Stats Tracking Helper

class GameStatsTracker {
    
    /// Records a game session with proper categorization
    static func recordSession(
        userDataManager: UserDataManager,
        gameType: String,
        score: Int,
        streak: Int,
        correctAnswers: Int,
        totalQuestions: Int
    ) {
        // Basic validation
        guard score >= 0, streak >= 0, correctAnswers >= 0,
              totalQuestions > 0, correctAnswers <= totalQuestions else {
            print("⚠️ Invalid game session data - not recording")
            return
        }
        
        // Record the main game session
        Task { @MainActor in
            userDataManager.recordGameSession(
                score: score,
                streak: streak,
                correctAnswers: correctAnswers,
                totalQuestions: totalQuestions,
                gameType: gameType
            )
        }
    }
}
