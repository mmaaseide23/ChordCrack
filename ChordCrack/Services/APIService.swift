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
        
        do {
            let user = try await supabase.signUp(email: email, password: password, username: username)
            
            // The trigger in the database will automatically create user_stats
            // But we'll verify it exists
            try await verifyUserStats(for: user)
            
            return user.userMetadata.username
        } catch {
            print("❌ Account creation failed: \(error)")
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws -> String {
        print("🔓 Signing in: \(email)")
        
        do {
            let user = try await supabase.signIn(email: email, password: password)
            
            // Verify user_stats exists (should be created by trigger, but double-check)
            try await verifyUserStats(for: user)
            
            return user.userMetadata.username
        } catch {
            print("❌ Sign in failed: \(error)")
            throw error
        }
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
    
    // MARK: - Helper Methods
    
    private func verifyUserStats(for user: User) async throws {
        print("🔍 Verifying user_stats for: \(user.userMetadata.username)")
        
        // Check if user_stats exists
        let stats: [UserStatsDBResponse] = try await supabase.performRequest(
            path: "/user_stats?id=eq.\(user.id)&select=*",
            responseType: [UserStatsDBResponse].self
        )
        
        if stats.isEmpty {
            print("⚠️ User stats missing, creating manually...")
            
            // This shouldn't happen with the trigger, but just in case
            let userStatsBody: [String: Any] = [
                "id": user.id,
                "username": user.userMetadata.username,
                "total_games": 0,
                "best_score": 0,
                "best_streak": 0,
                "average_score": 0.0,
                "total_correct": 0,
                "total_questions": 0
            ]
            
            do {
                try await supabase.performVoidRequest(
                    method: "POST",
                    path: "/user_stats",
                    body: userStatsBody
                )
                print("✅ User stats created successfully")
            } catch {
                print("⚠️ Could not create user stats (may already exist): \(error)")
            }
        } else {
            print("✅ User stats verified")
        }
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
            id: 1,
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
        
        guard let user = supabase.user else {
            throw APIError.notAuthenticated
        }
        
        // Fetch by user ID, not username
        let stats: [UserStatsDBResponse] = try await supabase.performRequest(
            path: "/user_stats?id=eq.\(user.id)&select=*",
            responseType: [UserStatsDBResponse].self
        )
        
        guard let userStats = stats.first else {
            print("⚠️ No stats found, returning defaults")
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
        guard let user = supabase.user else {
            throw APIError.notAuthenticated
        }
        
        let achievements: [UserAchievementDBResponse] = try await supabase.performRequest(
            path: "/user_achievements?user_id=eq.\(user.id)&select=achievement_id",
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
