import Foundation
import SwiftUI

/// Comprehensive chord type enumeration with professional organization
/// Clearly separates basic chords (for daily challenge) from advanced practice chords
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
    
    // Barre Chords
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
    
    // Blues/7th Chords
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
    case aMaj7 = "AMaj7"
    case cMaj7 = "CMaj7"
    case dMaj7 = "DMaj7"
    case eMaj7 = "EMaj7"
    case fMaj7 = "FMaj7"
    case gMaj7 = "GMaj7"
    
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
             .am7, .bm7, .cm7, .dm7, .em7, .fm7, .gm7,
             .aMaj7, .cMaj7, .dMaj7, .eMaj7, .fMaj7, .gMaj7:
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
    
    // MARK: - Finger Position Data
    
    var fingerPositions: [(string: String, fret: Int)] {
        switch self {
        // Basic Major Chords
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
            
        // Basic Minor Chords
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
            
        // Barre Chords
        case .fMajorBarre:
            return [("E2", 1), ("A3", 1), ("D3", 3), ("G3", 3), ("B4", 2), ("E4", 1)]
        case .gMajorBarre:
            return [("E2", 3), ("A3", 3), ("D3", 5), ("G3", 5), ("B4", 4), ("E4", 3)]
        case .aMajorBarre:
            return [("E2", 5), ("A3", 5), ("D3", 7), ("G3", 7), ("B4", 6), ("E4", 5)]
        case .bMajorBarre:
            return [("E2", 7), ("A3", 7), ("D3", 9), ("G3", 9), ("B4", 8), ("E4", 7)]
        case .cMajorBarre:
            return [("E2", 8), ("A3", 8), ("D3", 10), ("G3", 10), ("B4", 9), ("E4", 8)]
        case .dMajorBarre:
            return [("E2", 10), ("A3", 10), ("D3", 12), ("G3", 12), ("B4", 11), ("E4", 10)]
        case .fMinorBarre:
            return [("E2", 1), ("A3", 1), ("D3", 3), ("G3", 3), ("B4", 1), ("E4", 1)]
        case .gMinorBarre:
            return [("E2", 3), ("A3", 3), ("D3", 5), ("G3", 5), ("B4", 3), ("E4", 3)]
        case .aMinorBarre:
            return [("E2", 5), ("A3", 5), ("D3", 7), ("G3", 7), ("B4", 5), ("E4", 5)]
        case .bMinorBarre:
            return [("E2", 7), ("A3", 7), ("D3", 9), ("G3", 9), ("B4", 7), ("E4", 7)]
        case .cMinorBarre:
            return [("E2", 8), ("A3", 8), ("D3", 10), ("G3", 10), ("B4", 8), ("E4", 8)]
        case .dMinorBarre:
            return [("E2", 10), ("A3", 10), ("D3", 12), ("G3", 12), ("B4", 10), ("E4", 10)]
            
        // Blues/7th Chords
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
        case .aMaj7:
            return [("A3", 0), ("D3", 2), ("G3", 1), ("B4", 2), ("E4", 0)]
        case .cMaj7:
            return [("A3", 3), ("D3", 2), ("G3", 0), ("B4", 0), ("E4", 0)]
        case .dMaj7:
            return [("D3", 0), ("G3", 2), ("B4", 2), ("E4", 2)]
        case .eMaj7:
            return [("E2", 0), ("A3", 2), ("D3", 1), ("G3", 1), ("B4", 0), ("E4", 0)]
        case .fMaj7:
            return [("E2", 1), ("A3", 3), ("D3", 2), ("G3", 2), ("B4", 1), ("E4", 0)]
        case .gMaj7:
            return [("E2", 3), ("A3", 2), ("D3", 0), ("G3", 0), ("B4", 0), ("E4", 2)]
            
        // Power Chords (simplified - only essential strings)
        case .e5:
            return [("E2", 0), ("A3", 2)]
        case .a5:
            return [("A3", 0), ("D3", 2)]
        case .d5:
            return [("D3", 0), ("G3", 2)]
        case .g5:
            return [("G3", 0), ("B4", 3)]
        case .c5:
            return [("A3", 3), ("D3", 5)]
        case .f5:
            return [("E2", 1), ("A3", 3)]
        case .b5:
            return [("A3", 2), ("D3", 4)]
        case .fs5:
            return [("E2", 2), ("A3", 4)]
        case .cs5:
            return [("A3", 4), ("D3", 6)]
        case .gs5:
            return [("E2", 4), ("A3", 6)]
        case .ds5:
            return [("A3", 6), ("D3", 8)]
        case .as5:
            return [("A3", 1), ("D3", 3)]
        }
    }
    
    func getStringFiles() -> [String] {
        return fingerPositions.map { "\($0.string)_fret\($0.fret).m4a" }
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
        case .barre: return Color.purple
        case .blues: return Color.blue
        case .power: return Color.orange
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
