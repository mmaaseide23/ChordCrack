import Foundation
import Combine

class APIService: ObservableObject {
    private let supabase = SupabaseClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isAuthenticated = false
    @Published var currentUsername: String?
    @Published var currentEmail: String?
    
    init() {
        // Listen to authentication state changes
        supabase.$isAuthenticated
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
            }
            .store(in: &cancellables)
        
        supabase.$user
            .sink { [weak self] user in
                self?.currentEmail = user?.email
                self?.currentUsername = user?.userMetadata.username
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Methods
    
    func createAccount(email: String, password: String, username: String) async throws -> String {
        print("🔐 Creating account for: \(email) with username: \(username)")
        
        let user = try await supabase.signUp(email: email, password: password, username: username)
        return user.userMetadata.username
    }
    
    func signIn(email: String, password: String) async throws -> String {
        print("🔓 Signing in: \(email)")
        
        let user = try await supabase.signIn(email: email, password: password)
        return user.userMetadata.username
    }
    
    func signOut() {
        Task {
            try? await supabase.signOut()
        }
    }
    
    func checkAuthState() {
        // Authentication state is automatically managed by SupabaseClient
        // No need for manual checks as it's handled by Combine publishers
    }
    
    // MARK: - Game Data Methods
    
    func submitGameSession(_ gameSession: GameSession) async throws -> GameSessionResponse {
        print("📊 Submitting game session for: \(gameSession.username)")
        
        guard let user = supabase.user else {
            throw APIError.notAuthenticated
        }
        
        // Submit game session
        let gameSessionBody: [String: Any] = [
            "user_id": user.id,
            "username": gameSession.username,
            "score": gameSession.score,
            "streak": gameSession.streak,
            "correct_answers": gameSession.correctAnswers,
            "total_questions": gameSession.totalQuestions,
            "game_type": gameSession.gameType
        ]
        
        let _: [GameSessionDBResponse] = try await supabase.performRequest(
            method: "POST",
            path: "/game_sessions",
            body: gameSessionBody,
            responseType: [GameSessionDBResponse].self
        )
        
        // Update user stats using the database function
        try await supabase.performVoidRequest(
            method: "POST",
            path: "/rpc/update_user_stats",
            body: [
                "p_score": gameSession.score,
                "p_streak": gameSession.streak,
                "p_correct": gameSession.correctAnswers,
                "p_total": gameSession.totalQuestions
            ]
        )
        
        return GameSessionResponse(
            id: 1, // We don't actually need this ID in the app
            username: gameSession.username,
            score: gameSession.score,
            streak: gameSession.streak,
            correctAnswers: gameSession.correctAnswers,
            totalQuestions: gameSession.totalQuestions,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
    }
    
    func getUserStats(username: String) async throws -> UserStatsResponse {
        print("📈 Fetching stats for: \(username)")
        
        guard supabase.user != nil else {
            throw APIError.notAuthenticated
        }
        
        let stats: [UserStatsDBResponse] = try await supabase.performRequest(
            path: "/user_stats?select=*",
            responseType: [UserStatsDBResponse].self
        )
        
        guard let userStats = stats.first else {
            // Return default stats if none exist
            return UserStatsResponse(
                totalGames: 0,
                bestScore: 0,
                bestStreak: 0,
                averageScore: 0.0,
                totalCorrect: 0,
                totalQuestions: 0
            )
        }
        
        return UserStatsResponse(
            totalGames: userStats.totalGames,
            bestScore: userStats.bestScore,
            bestStreak: userStats.bestStreak,
            averageScore: userStats.averageScore,
            totalCorrect: userStats.totalCorrect,
            totalQuestions: userStats.totalQuestions
        )
    }
    
    func getLeaderboard(limit: Int = 10) async throws -> [LeaderboardEntry] {
        print("🏆 Fetching leaderboard")
        
        let leaderboard: [UserStatsDBResponse] = try await supabase.performRequest(
            path: "/user_stats?select=username,best_score,total_games&order=best_score.desc&limit=\(limit)",
            responseType: [UserStatsDBResponse].self
        )
        
        return leaderboard.enumerated().map { index, stats in
            LeaderboardEntry(
                rank: index + 1,
                username: stats.username,
                bestScore: stats.bestScore,
                totalGames: stats.totalGames
            )
        }
    }
    
    func getUserAchievements() async throws -> [String] {
        guard supabase.user != nil else {
            throw APIError.notAuthenticated
        }
        
        let achievements: [UserAchievementDBResponse] = try await supabase.performRequest(
            path: "/user_achievements?select=achievement_id",
            responseType: [UserAchievementDBResponse].self
        )
        
        return achievements.map { $0.achievementId }
    }
    
    func unlockAchievement(_ achievementId: String) async throws {
        guard let user = supabase.user else {
            throw APIError.notAuthenticated
        }
        
        try await supabase.performVoidRequest(
            method: "POST",
            path: "/user_achievements",
            body: [
                "user_id": user.id,
                "achievement_id": achievementId
            ]
        )
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
    var id: String { username } // Use username as unique identifier
    let rank: Int
    let username: String
    let bestScore: Int
    let totalGames: Int
}

// MARK: - Keep existing response models for compatibility

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
