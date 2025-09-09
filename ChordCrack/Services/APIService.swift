import Foundation

/// API Service for managing user data and game statistics with Supabase
class APIService {
    private let supabase = SupabaseClient.shared
    
    // MARK: - Authentication
    
    func createAccount(email: String, password: String, username: String) async throws -> String {
        // Step 1: Create the user account with Supabase Auth
        let user = try await supabase.signUp(email: email, password: password, username: username)
        
        // Step 2: Try to create initial user_stats with the username we know
        Task {
            // Do this in background - don't block signup
            try? await createInitialUserStats(userId: user.id, username: username)
        }
        
        return username
    }
    
    func signIn(email: String, password: String) async throws -> String {
        let user = try await supabase.signIn(email: email, password: password)
        
        // Ensure user_stats exists (in case of older accounts or failed initial creation)
        try await ensureUserStatsExists(userId: user.id, username: user.userMetadata.username)
        
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
        
        // Use upsert to handle conflicts - this will create if doesn't exist, or do nothing if exists
        do {
            try await supabase.performVoidRequest(
                method: "POST",
                path: "user_stats",
                body: statsData,
                headers: ["Prefer": "resolution=ignore-duplicates"]
            )
            print("Successfully created initial user stats for user: \(userId)")
        } catch {
            print("Failed to create initial user stats: \(error)")
            // Re-throw to allow retry logic in caller
            throw error
        }
    }
    
    private func ensureUserStatsExists(userId: String, username: String) async throws {
        do {
            // First check if stats exist
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)&select=id",
                responseType: [[String: String]].self
            )
            
            // If no stats found, create them
            if response.isEmpty {
                print("No stats found for user \(userId), creating initial stats")
                try await createInitialUserStats(userId: userId, username: username)
            }
        } catch APIError.notAuthenticated {
            // If not authenticated, don't try to create stats
            throw APIError.notAuthenticated
        } catch {
            print("Error ensuring user stats exist: \(error)")
            // Don't throw - app can still function without stats initially
        }
    }
    
    func getUserStats(username: String) async throws -> UserStatsResponse {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        return try await getUserStats(userId: userId, username: username)
    }
    
    private func getUserStats(userId: String, username: String) async throws -> UserStatsResponse {
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)&select=*",
                responseType: [UserStatsDBResponse].self
            )
            
            guard let statsResponse = response.first else {
                // If no stats exist yet, ensure they're created and return defaults
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
            
        } catch {
            print("Error fetching user stats: \(error)")
            throw error
        }
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
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let response = try await supabase.performRequest(
                method: "POST",
                path: "game_sessions",
                body: sessionData,
                responseType: GameSessionDBResponse.self
            )
            
            // Update user stats after game session
            try await updateUserStats(
                userId: userId,
                username: session.username,
                score: session.score,
                streak: session.streak,
                correctAnswers: session.correctAnswers,
                totalQuestions: session.totalQuestions,
                gameType: session.gameType
            )
            
            return String(response.id)
            
        } catch {
            print("Error submitting game session: \(error)")
            throw error
        }
    }
    
    private func updateUserStats(
        userId: String,
        username: String,
        score: Int,
        streak: Int,
        correctAnswers: Int,
        totalQuestions: Int,
        gameType: String
    ) async throws {
        do {
            // Ensure stats exist first
            try await ensureUserStatsExists(userId: userId, username: username)
            
            // Get current stats
            let currentStats = try await getUserStats(userId: userId, username: username)
            
            // Calculate new values
            let newTotalGames = currentStats.totalGames + 1
            let newBestScore = max(currentStats.bestScore, score)
            let newBestStreak = max(currentStats.bestStreak, streak)
            let newTotalCorrect = currentStats.totalCorrect + correctAnswers
            let newTotalQuestions = currentStats.totalQuestions + totalQuestions
            let newAverageScore = Double(currentStats.totalGames * Int(currentStats.averageScore) + score) / Double(newTotalGames)
            
            // Calculate category-specific accuracy (simplified for now - you can expand this)
            let gameAccuracy = totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) * 100 : 0
            
            // Update stats using PATCH to update existing record
            let updateData: [String: Any] = [
                "total_games": newTotalGames,
                "best_score": newBestScore,
                "best_streak": newBestStreak,
                "average_score": newAverageScore,
                "total_correct": newTotalCorrect,
                "total_questions": newTotalQuestions,
                "basic_chord_accuracy": gameAccuracy, // For daily challenge
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            // Use performVoidRequest since we don't need the response
            try await supabase.performVoidRequest(
                method: "PATCH",
                path: "user_stats?id=eq.\(userId)",
                body: updateData
            )
            
        } catch {
            print("Error updating user stats: \(error)")
            throw error
        }
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
            print("Error fetching user achievements: \(error)")
            // Return empty array instead of throwing - achievements are not critical
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
            // Use upsert to avoid duplicate key errors
            try await supabase.performVoidRequest(
                method: "POST",
                path: "user_achievements",
                body: achievementData,
                headers: ["Prefer": "resolution=ignore-duplicates"]
            )
            
        } catch {
            print("Error unlocking achievement \(achievementId): \(error)")
            // Don't throw - achievements are not critical to core functionality
        }
    }
}
