import Foundation

// MARK: - User Models

struct User {
    let id: String
    let email: String
    let userMetadata: UserMetadata
}

struct UserMetadata {
    let username: String
}

// MARK: - Game Session Model

struct GameSession: Codable {
    let id: UUID
    let username: String
    let score: Int
    let streak: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let gameType: String
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

// MARK: - Database Response Models

struct GameSessionDBResponse: Codable {
    let id: Int
    let userId: String
    let username: String
    let score: Int
    let streak: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let gameType: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username, score, streak
        case correctAnswers = "correct_answers"
        case totalQuestions = "total_questions"
        case gameType = "game_type"
        case createdAt = "created_at"
    }
}

struct UserStatsDBResponse: Codable {
    let id: String?
    let username: String
    let totalGames: Int
    let bestScore: Int
    let bestStreak: Int
    let averageScore: Double
    let totalCorrect: Int
    let totalQuestions: Int
    
    enum CodingKeys: String, CodingKey {
        case id, username
        case totalGames = "total_games"
        case bestScore = "best_score"
        case bestStreak = "best_streak"
        case averageScore = "average_score"
        case totalCorrect = "total_correct"
        case totalQuestions = "total_questions"
    }
}

struct UserAchievementDBResponse: Codable {
    let achievementId: String
    let unlockedAt: String
    
    enum CodingKeys: String, CodingKey {
        case achievementId = "achievement_id"
        case unlockedAt = "unlocked_at"
    }
}

struct LeaderboardEntry: Codable, Identifiable {
    var id: String { username }
    let rank: Int
    let username: String
    let bestScore: Int
    let totalGames: Int
}

// MARK: - API Response Models

struct GameSessionResponse: Codable {
    let id: Int
    let username: String
    let score: Int
    let streak: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, username, score, streak
        case correctAnswers = "correct_answers"
        case totalQuestions = "total_questions"
        case createdAt = "created_at"
    }
}

struct UserStatsResponse: Codable {
    let totalGames: Int
    let bestScore: Int
    let bestStreak: Int
    let averageScore: Double
    let totalCorrect: Int
    let totalQuestions: Int
    
    enum CodingKeys: String, CodingKey {
        case totalGames = "total_games"
        case bestScore = "best_score"
        case bestStreak = "best_streak"
        case averageScore = "average_score"
        case totalCorrect = "total_correct"
        case totalQuestions = "total_questions"
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidResponse
    case networkError
    case decodingError
    case invalidCredentials
    case userAlreadyExists
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .networkError:
            return "Network connection error"
        case .decodingError:
            return "Data parsing error"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userAlreadyExists:
            return "User already exists"
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}
