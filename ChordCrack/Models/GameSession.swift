import Foundation

/// Enhanced game session model supporting different game types and statistics
struct GameSession: Codable {
    let id: UUID
    let username: String
    let score: Int
    let streak: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let gameType: String // Simplified to avoid conflicts
    let createdAt: Date
    
    init(username: String, score: Int, streak: Int, correctAnswers: Int, totalQuestions: Int, gameType: String = "dailyChallenge") {
        self.id = UUID()
        self.username = username
        self.score = score
        self.streak = streak
        self.correctAnswers = correctAnswers
        self.totalQuestions = totalQuestions
        self.gameType = gameType
        self.createdAt = Date()
    }
}
