import Foundation

struct CategoryStats: Codable {
    var sessionsPlayed: Int = 0
    var bestScore: Int = 0
    var correctAnswers: Int = 0
    var totalQuestions: Int = 0
    var totalScore: Int = 0
    var averageScore: Double = 0.0

    var accuracy: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return Double(correctAnswers) / Double(totalQuestions) * 100
    }
}
