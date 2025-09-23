import Foundation

/// API Service for managing user data and game statistics with Supabase (Updated for Reverse Mode)
class APIService {
    private let supabase = SupabaseClient.shared
    
    // MARK: - Username Validation & Safety (Existing code remains unchanged)
    // ... [Keep all existing validation code]
    
    // MARK: - Reverse Mode Methods (NEW)
    
    /// Submit a reverse mode game session
    func submitReverseModeSession(_ session: ReverseModeSession) async throws -> String {
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
            "hints_used": session.hintsUsed,
            "sound_hints_used": session.soundHintsUsed,
            "theory_hints_used": session.theoryHintsUsed,
            "created_at": ISO8601DateFormatter().string(from: session.createdAt)
        ]
        
        // Submit to reverse_mode_sessions table
        let response: [ReverseModeSessionDBResponse]
        do {
            let singleResponse = try await supabase.performRequest(
                method: "POST",
                path: "reverse_mode_sessions",
                body: sessionData,
                responseType: ReverseModeSessionDBResponse.self
            )
            response = [singleResponse]
        } catch {
            response = try await supabase.performRequest(
                method: "POST",
                path: "reverse_mode_sessions",
                body: sessionData,
                responseType: [ReverseModeSessionDBResponse].self
            )
        }
        
        guard let sessionResponse = response.first else {
            throw APIError.invalidResponse
        }
        
        // Update reverse mode stats
        do {
            try await updateReverseModeStats(
                userId: userId,
                username: session.username,
                score: session.score,
                streak: session.streak,
                correctAnswers: session.correctAnswers,
                totalQuestions: session.totalQuestions,
                gameType: session.gameType
            )
        } catch {
            // Don't throw - session was still recorded
        }
        
        return String(sessionResponse.id)
    }
    
    /// Update reverse mode statistics
    private func updateReverseModeStats(
        userId: String,
        username: String,
        score: Int,
        streak: Int,
        correctAnswers: Int,
        totalQuestions: Int,
        gameType: String
    ) async throws {
        // Ensure reverse mode stats exist
        try await ensureReverseModeStatsExists(userId: userId, username: username)
        
        // Get current stats
        let currentStats = try await getReverseModeStats(userId: userId)
        
        // Calculate new stats
        let newTotalGames = currentStats.totalGames + 1
        let newBestScore = max(currentStats.bestScore, score)
        let newBestStreak = max(currentStats.bestStreak, streak)
        let newTotalCorrect = currentStats.totalCorrect + correctAnswers
        let newTotalQuestions = currentStats.totalQuestions + totalQuestions
        
        let totalScorePoints = (currentStats.totalGames * Int(currentStats.averageScore)) + score
        let newAverageScore = Double(totalScorePoints) / Double(newTotalGames)
        
        // Calculate XP and level
        let xpGained = score / 10 + streak * 5
        let newTotalXP = currentStats.totalXp + xpGained
        let newLevel = (newTotalXP / 1000) + 1
        
        // Calculate category accuracy
        let gameAccuracy = totalQuestions > 0 ? Double(correctAnswers) / Double(totalQuestions) * 100 : 0
        
        var updateData: [String: Any] = [
            "total_games": newTotalGames,
            "best_score": newBestScore,
            "best_streak": newBestStreak,
            "average_score": newAverageScore,
            "total_correct": newTotalCorrect,
            "total_questions": newTotalQuestions,
            "total_xp": newTotalXP,
            "current_level": newLevel,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Update category-specific accuracy
        switch gameType {
        case "reverseDailyChallenge", "reverseBasicPractice":
            updateData["basic_chord_accuracy"] = gameAccuracy
        case "reversePowerPractice":
            updateData["power_chord_accuracy"] = gameAccuracy
        case "reverseBarrePractice":
            updateData["barre_chord_accuracy"] = gameAccuracy
        case "reverseBluesPractice":
            updateData["blues_chord_accuracy"] = gameAccuracy
        default:
            break
        }
        
        try await supabase.performVoidRequest(
            method: "PATCH",
            path: "reverse_mode_stats?id=eq.\(userId)",
            body: updateData
        )
    }
    
    /// Ensure reverse mode stats exist for user
    private func ensureReverseModeStatsExists(userId: String, username: String) async throws {
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "reverse_mode_stats?id=eq.\(userId)&select=id",
                responseType: [[String: String]].self
            )
            
            if response.isEmpty {
                // Create initial reverse mode stats
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
                    "total_xp": 0,
                    "current_level": 1,
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ]
                
                try await supabase.performVoidRequest(
                    method: "POST",
                    path: "reverse_mode_stats",
                    body: statsData,
                    headers: ["Prefer": "resolution=ignore-duplicates"]
                )
            }
        } catch {
            // Try to create if check failed
            try? await createInitialReverseModeStats(userId: userId, username: username)
        }
    }
    
    /// Create initial reverse mode stats
    private func createInitialReverseModeStats(userId: String, username: String) async throws {
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
            "total_xp": 0,
            "current_level": 1,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase.performVoidRequest(
            method: "POST",
            path: "reverse_mode_stats",
            body: statsData,
            headers: ["Prefer": "resolution=ignore-duplicates"]
        )
    }
    
    /// Get reverse mode stats for user
    func getReverseModeStats(userId: String) async throws -> ReverseModeStatsDBResponse {
        let response = try await supabase.performRequest(
            method: "GET",
            path: "reverse_mode_stats?id=eq.\(userId)&select=*",
            responseType: [ReverseModeStatsDBResponse].self
        )
        
        guard let stats = response.first else {
            // Return default stats
            return ReverseModeStatsDBResponse(
                id: userId,
                username: supabase.user?.userMetadata.username ?? "",
                totalGames: 0,
                bestScore: 0,
                bestStreak: 0,
                averageScore: 0,
                totalCorrect: 0,
                totalQuestions: 0,
                powerChordAccuracy: 0,
                barreChordAccuracy: 0,
                bluesChordAccuracy: 0,
                basicChordAccuracy: 0,
                totalXp: 0,
                currentLevel: 1
            )
        }
        
        return stats
    }
    
    /// Get reverse mode leaderboard
    func getReverseModeLeaderboard() async throws -> [ReverseModeLeaderboardEntry] {
        let response = try await supabase.performRequest(
            method: "GET",
            path: "reverse_mode_leaderboard?select=*&limit=100",
            responseType: [ReverseModeLeaderboardDBResponse].self
        )
        
        return response.map { entry in
            ReverseModeLeaderboardEntry(
                rank: entry.rank,
                username: entry.username,
                bestScore: entry.bestScore,
                totalGames: entry.totalGames,
                currentLevel: entry.currentLevel,
                totalXp: entry.totalXp
            )
        }
    }
    
    /// Unlock reverse mode achievement
    func unlockReverseModeAchievement(_ achievementId: String) async throws {
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
                path: "reverse_mode_achievements",
                body: achievementData,
                headers: ["Prefer": "resolution=ignore-duplicates"]
            )
        } catch {
            // Don't throw - achievements are not critical
        }
    }
    
    /// Get user's reverse mode achievements
    func getReverseModeAchievements() async throws -> [String] {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "reverse_mode_achievements?user_id=eq.\(userId)&select=achievement_id",
                responseType: [ReverseModeAchievementDBResponse].self
            )
            return response.map { $0.achievementId }
        } catch {
            return []
        }
    }
    
    // MARK: - User Preferences Management (NEW)
    
    /// Update user preferences (including reverse mode toggle)
    func updateUserPreferences(_ preferences: UserPreferences) async throws {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        let preferencesData: [String: Any] = [
            "user_id": userId,
            "reverse_mode_enabled": preferences.reverseModeEnabled,
            "preferred_theme": preferences.preferredTheme,
            "sound_effects_enabled": preferences.soundEffectsEnabled,
            "haptic_feedback_enabled": preferences.hapticFeedbackEnabled,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Use UPSERT to create or update
        try await supabase.performVoidRequest(
            method: "POST",
            path: "user_preferences",
            body: preferencesData,
            headers: ["Prefer": "resolution=merge-duplicates"]
        )
    }
    
    /// Get user preferences
    func getUserPreferences() async throws -> UserPreferences {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        let response = try await supabase.performRequest(
            method: "GET",
            path: "user_preferences?user_id=eq.\(userId)&select=*",
            responseType: [UserPreferencesDBResponse].self
        )
        
        guard let prefs = response.first else {
            return UserPreferences.default
        }
        
        return UserPreferences(
            reverseModeEnabled: prefs.reverseModeEnabled,
            preferredTheme: prefs.preferredTheme,
            soundEffectsEnabled: prefs.soundEffectsEnabled,
            hapticFeedbackEnabled: prefs.hapticFeedbackEnabled
        )
    }
    
    // MARK: - Keep all existing methods unchanged
    // ... [All existing authentication, validation, and normal mode methods remain]
}

// MARK: - Additional Response Models for Reverse Mode

struct ReverseModeLeaderboardDBResponse: Codable {
    let rank: Int
    let userId: String
    let username: String
    let bestScore: Int
    let totalGames: Int
    let currentLevel: Int
    let totalXp: Int
    
    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case username
        case bestScore = "best_score"
        case totalGames = "total_games"
        case currentLevel = "current_level"
        case totalXp = "total_xp"
    }
}

struct ReverseModeAchievementDBResponse: Codable {
    let achievementId: String
    
    enum CodingKeys: String, CodingKey {
        case achievementId = "achievement_id"
    }
}
