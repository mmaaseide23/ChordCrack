import Foundation

/// Controls how many chord options appear in the selection grid.
/// Easy shows fewer distractors, Hard shows all chords in the category.
enum DifficultyLevel: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    /// How many total chord options to show in the selection grid
    var optionCount: Int {
        switch self {
        case .easy: return 6
        case .medium: return 10
        case .hard: return 0 // 0 means show all
        }
    }

    var description: String {
        switch self {
        case .easy: return "Fewer options to choose from"
        case .medium: return "Moderate number of options"
        case .hard: return "All chords shown"
        }
    }

    var icon: String {
        switch self {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "bolt.fill"
        }
    }

    /// Returns the current user-selected difficulty from UserDefaults
    static var current: DifficultyLevel {
        guard let raw = UserDefaults.standard.string(forKey: "difficultyLevel"),
              let level = DifficultyLevel(rawValue: raw) else {
            return .medium
        }
        return level
    }

    /// Filters a chord pool to the appropriate number of options for this difficulty.
    /// The correct chord is always included.
    func filteredChords(from pool: [ChordType], correctChord: ChordType) -> [ChordType] {
        // Hard mode or small pools: show everything
        guard optionCount > 0, pool.count > optionCount else {
            return pool
        }

        // Always include the correct answer
        var result: Set<ChordType> = [correctChord]

        // Fill remaining slots with random distractors from the same pool
        var shuffled = pool.filter { $0 != correctChord }.shuffled()
        let needed = optionCount - 1

        for chord in shuffled.prefix(needed) {
            result.insert(chord)
        }

        // Return in a stable order (alphabetical by raw value) so grid doesn't jump around
        return result.sorted { $0.rawValue < $1.rawValue }
    }
}
