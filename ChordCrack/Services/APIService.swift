import Foundation

/// API Service for managing user data and game statistics with Supabase
class APIService {
    private let supabase = SupabaseClient.shared
    
    // MARK: - Authentication
    
    func createAccount(email: String, password: String, username: String) async throws -> String {
        let user = try await supabase.signUp(email: email, password: password, username: username)
        
        do {
            try await createInitialUserStats(userId: user.id, username: username)
        } catch {
            // Don't throw - account is still created, stats can be created later
        }
        
        return username
    }
    
    func signIn(email: String, password: String) async throws -> String {
        let user = try await supabase.signIn(email: email, password: password)
        try await ensureUserStatsExists(userId: user.id, username: user.userMetadata.username)
        return user.userMetadata.username
    }
    
    func signInWithApple() async throws -> String {
        print("🍎 APIService: Starting Apple Sign-In with Supabase OAuth")
        
        let user = try await supabase.signInWithApple()
        
        print("🍎 APIService: Apple Sign-In successful, ensuring user stats exist")
        try await ensureUserStatsExists(userId: user.id, username: user.userMetadata.username)
        
        print("🍎 APIService: User setup complete")
        return user.userMetadata.username
    }
    
    func signOut() {
        Task {
            try? await supabase.signOut()
        }
    }
    
    // MARK: - User Stats Management
    
    private func createInitialUserStats(userId: String, username: String) async throws {
        let statsData: [String: Any] = [
            "id": userId,
            "username": username,
            "total_games": 0,
            "best_score": 0,
            "best_streak": 0,
            "average_score": 0.0,
            "total_correct": 0,
            "total_questions": 0,
            "power_chord_accuracy": 0.0,
            "barre_chord_accuracy": 0.0,
            "blues_chord_accuracy": 0.0,
            "basic_chord_accuracy": 0.0,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase.performVoidRequest(
            method: "POST",
            path: "user_stats",
            body: statsData,
            headers: ["Prefer": "resolution=ignore-duplicates"]
        )
    }
    
    private func ensureUserStatsExists(userId: String, username: String) async throws {
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)&select=id",
                responseType: [[String: String]].self
            )
            
            if response.isEmpty {
                try await createInitialUserStats(userId: userId, username: username)
            }
        } catch APIError.notAuthenticated {
            throw APIError.notAuthenticated
        } catch {
            try? await createInitialUserStats(userId: userId, username: username)
        }
    }
    
    func getUserStats(username: String) async throws -> UserStatsResponse {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        return try await getUserStats(userId: userId, username: username)
    }
    
    private func getUserStats(userId: String, username: String) async throws -> UserStatsResponse {
        let response = try await supabase.performRequest(
            method: "GET",
            path: "user_stats?id=eq.\(userId)&select=*",
            responseType: [UserStatsDBResponse].self
        )
        
        guard let statsResponse = response.first else {
            try await ensureUserStatsExists(userId: userId, username: username)
            return UserStatsResponse(
                totalGames: 0,
                bestScore: 0,
                bestStreak: 0,
                averageScore: 0,
                totalCorrect: 0,
                totalQuestions: 0
            )
        }
        
        return UserStatsResponse(
            totalGames: statsResponse.totalGames,
            bestScore: statsResponse.bestScore,
            bestStreak: statsResponse.bestStreak,
            averageScore: statsResponse.averageScore,
            totalCorrect: statsResponse.totalCorrect,
            totalQuestions: statsResponse.totalQuestions
        )
    }
    
    // MARK: - Game Session Management
    
    @discardableResult
    func submitGameSession(_ session: GameSession) async throws -> String {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        let sessionData: [String: Any] = [
            "user_id": userId,
            "username": session.username,
            "score": session.score,
            "streak": session.streak,
            "correct_answers": session.correctAnswers,
            "total_questions": session.totalQuestions,
            "game_type": session.gameType,
            "created_at": ISO8601DateFormatter().string(from: session.createdAt)
        ]
        
        // Handle both single object and array responses from Supabase
        let response: [GameSessionDBResponse]
        do {
            let singleResponse = try await supabase.performRequest(
                method: "POST",
                path: "game_sessions",
                body: sessionData,
                responseType: GameSessionDBResponse.self
            )
            response = [singleResponse]
        } catch {
            response = try await supabase.performRequest(
                method: "POST",
                path: "game_sessions",
                body: sessionData,
                responseType: [GameSessionDBResponse].self
            )
        }
        
        guard let sessionResponse = response.first else {
            throw APIError.invalidResponse
        }
        
        // Update user stats after successful submission
        do {
            try await updateUserStatsAfterGameSession(
                userId: userId,
                username: session.username,
                score: session.score,
                streak: session.streak,
                correctAnswers: session.correctAnswers,
                totalQuestions: session.totalQuestions,
                gameType: session.gameType
            )
        } catch {
            // Don't throw here - the game session was still recorded
        }
        
        return String(sessionResponse.id)
    }
    
    private func updateUserStatsAfterGameSession(
        userId: String,
        username: String,
        score: Int,
        streak: Int,
        correctAnswers: Int,
        totalQuestions: Int,
        gameType: String
    ) async throws {
        try await ensureUserStatsExists(userId: userId, username: username)
        
        let currentStats = try await getUserStats(userId: userId, username: username)
        
        let newTotalGames = currentStats.totalGames + 1
        let newBestScore = max(currentStats.bestScore, score)
        let newBestStreak = max(currentStats.bestStreak, streak)
        let newTotalCorrect = currentStats.totalCorrect + correctAnswers
        let newTotalQuestions = currentStats.totalQuestions + totalQuestions
        
        let totalScorePoints = (currentStats.totalGames * Int(currentStats.averageScore)) + score
        let newAverageScore = Double(totalScorePoints) / Double(newTotalGames)
        
        let gameAccuracy = totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) * 100 : 0
        
        var updateData: [String: Any] = [
            "total_games": newTotalGames,
            "best_score": newBestScore,
            "best_streak": newBestStreak,
            "average_score": newAverageScore,
            "total_correct": newTotalCorrect,
            "total_questions": newTotalQuestions,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Update category-specific accuracy based on game type
        switch gameType {
        case GameTypeConstants.dailyChallenge, GameTypeConstants.basicChords:
            updateData["basic_chord_accuracy"] = gameAccuracy
        case GameTypeConstants.powerChords:
            updateData["power_chord_accuracy"] = gameAccuracy
        case GameTypeConstants.barreChords:
            updateData["barre_chord_accuracy"] = gameAccuracy
        case GameTypeConstants.bluesChords:
            updateData["blues_chord_accuracy"] = gameAccuracy
        default:
            break
        }
        
        try await supabase.performVoidRequest(
            method: "PATCH",
            path: "user_stats?id=eq.\(userId)",
            body: updateData
        )
    }
    
    // MARK: - Achievements Management
    
    func getUserAchievements() async throws -> [String] {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_achievements?user_id=eq.\(userId)&select=achievement_id",
                responseType: [UserAchievementDBResponse].self
            )
            return response.map { $0.achievementId }
        } catch {
            return []
        }
    }
    
    func unlockAchievement(_ achievementId: String) async throws {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        let achievementData: [String: Any] = [
            "user_id": userId,
            "achievement_id": achievementId,
            "unlocked_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            try await supabase.performVoidRequest(
                method: "POST",
                path: "user_achievements",
                body: achievementData,
                headers: ["Prefer": "resolution=ignore-duplicates"]
            )
        } catch {
            // Don't throw - achievements are not critical
        }
    }
}
