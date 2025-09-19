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
        
        print("🍎 APIService: Apple Sign-In successful")
        print("🍎 APIService: Received user.id: \(user.id)")
        print("🍎 APIService: Received user.userMetadata.username: \(user.userMetadata.username)")
        
        // First, check if user already has VALID stats in database
        // We need to filter out "PendingUsername" as invalid
        let existingUsername = try await getExistingUsername(userId: user.id)
        
        // Check if the username is valid (not a placeholder)
        let isValidUsername = existingUsername != nil &&
                              existingUsername != "PendingUsername" &&
                              existingUsername != "Apple User" &&
                              !existingUsername!.isEmpty
        
        if isValidUsername, let validUsername = existingUsername {
            // User already exists with a valid username
            print("🍎 APIService: Found existing valid username in database: \(validUsername)")
            
            // Update the SupabaseClient's user object with the correct username
            await MainActor.run {
                if let currentUser = supabase.user {
                    supabase.user = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        userMetadata: UserMetadata(username: validUsername)
                    )
                }
            }
            
            return validUsername
        }
        
        // Either new user OR user with invalid/placeholder username
        print("🍎 APIService: No valid username found, generating new one")
        
        let finalUsername = try await generateUniqueUsername()
        print("🍎 APIService: Generated new username: \(finalUsername)")
        
        // CRITICAL FIX: Update or create user stats with the CORRECT username
        // If user stats exist with PendingUsername, we need to UPDATE them
        if existingUsername == "PendingUsername" {
            // Update existing record with the correct username
            print("🍎 APIService: Updating existing user_stats from PendingUsername to \(finalUsername)")
            
            let updateData: [String: Any] = [
                "username": finalUsername,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            try await supabase.performVoidRequest(
                method: "PATCH",
                path: "user_stats?id=eq.\(user.id)",
                body: updateData
            )
        } else {
            // Create new user stats
            try await ensureUserStatsExists(userId: user.id, username: finalUsername)
        }
        
        // Update the SupabaseClient's user object with the new username
        await MainActor.run {
            if let currentUser = supabase.user {
                supabase.user = User(
                    id: currentUser.id,
                    email: currentUser.email,
                    userMetadata: UserMetadata(username: finalUsername)
                )
            }
        }
        
        print("🍎 APIService: User setup complete with username: \(finalUsername)")
        return finalUsername
    }
    
    // MARK: - Username Management
    
    func updateUsername(_ newUsername: String) async throws {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // Validate username is unique
        let isUnique = try await isUsernameUnique(newUsername)
        guard isUnique else {
            throw APIError.userAlreadyExists
        }
        
        // Update username in user_stats table
        let updateData: [String: Any] = [
            "username": newUsername,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase.performVoidRequest(
            method: "PATCH",
            path: "user_stats?id=eq.\(userId)",
            body: updateData
        )
        
        // Update local user object
        await MainActor.run {
            if let currentUser = supabase.user {
                supabase.user = User(
                    id: currentUser.id,
                    email: currentUser.email,
                    userMetadata: UserMetadata(username: newUsername)
                )
            }
        }
    }
    
    private func getExistingUsername(userId: String) async throws -> String? {
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)&select=username",
                responseType: [UserStatsUsernameResponse].self
            )
            
            return response.first?.username
        } catch {
            return nil
        }
    }
    
    private func generateUniqueUsername() async throws -> String {
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            let candidateUsername = generateRandomUsername()
            
            // Check if username is unique
            if try await isUsernameUnique(candidateUsername) {
                return candidateUsername
            }
            
            attempts += 1
        }
        
        // If we can't find a unique username after maxAttempts, append timestamp
        let baseUsername = generateRandomUsername()
        let timestamp = String(Int(Date().timeIntervalSince1970) % 10000)
        return "\(baseUsername)\(timestamp)"
    }
    
    private func isUsernameUnique(_ username: String) async throws -> Bool {
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?username=eq.\(username)&select=username",
                responseType: [[String: String]].self
            )
            return response.isEmpty
        } catch {
            // If we can't check uniqueness, assume it's not unique to be safe
            return false
        }
    }
    
    private func generateRandomUsername() -> String {
        let adjectives = ["Swift", "Chord", "Music", "Guitar", "Rock", "Blues", "Jazz", "Melody", "Harmony", "Rhythm"]
        let nouns = ["Player", "Master", "Expert", "Wizard", "Hero", "Star", "Pro", "Ace", "Champion", "Legend"]
        
        let randomAdjective = adjectives.randomElement() ?? "Music"
        let randomNoun = nouns.randomElement() ?? "Player"
        let randomNumber = Int.random(in: 10...99)
        
        return "\(randomAdjective)\(randomNoun)\(randomNumber)"
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
        // Don't create stats with placeholder usernames
        guard username != "PendingUsername" && username != "Apple User" else {
            print("⚠️ Refusing to create user_stats with placeholder username: \(username)")
            return
        }
        
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)&select=id,username",
                responseType: [UserStatsUsernameResponse].self
            )
            
            if response.isEmpty {
                // No stats exist, create them
                try await createInitialUserStats(userId: userId, username: username)
            } else if let existing = response.first {
                // Stats exist, check if username needs updating
                if existing.username == "PendingUsername" || existing.username == "Apple User" {
                    // Update the username
                    print("🔄 Updating user_stats username from '\(existing.username)' to '\(username)'")
                    
                    let updateData: [String: Any] = [
                        "username": username,
                        "updated_at": ISO8601DateFormatter().string(from: Date())
                    ]
                    
                    try await supabase.performVoidRequest(
                        method: "PATCH",
                        path: "user_stats?id=eq.\(userId)",
                        body: updateData
                    )
                }
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

// MARK: - Supporting Response Model

struct UserStatsUsernameResponse: Codable {
    let id: String?
    let username: String
}
