import Foundation

/// Per-chord accuracy tracking data.
/// Used by the Stats Dashboard to identify weakest chords.
struct ChordAccuracyData: Codable, Equatable {
    var correct: Int
    var total: Int

    init(correct: Int = 0, total: Int = 0) {
        self.correct = correct
        self.total = total
    }

    var accuracy: Double {
        guard total > 0 else { return 0.0 }
        return Double(correct) / Double(total) * 100
    }

    mutating func record(wasCorrect: Bool) {
        total += 1
        if wasCorrect {
            correct += 1
        }
    }
}
