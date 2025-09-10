import Foundation

@MainActor
class AccountManagementService: ObservableObject {
    static let shared = AccountManagementService()
    
    private let supabase = SupabaseClient.shared
    
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private init() {}
    
    /// Export all user data (GDPR compliance)
    func exportUserData() async throws -> String {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            // Fetch user stats
            let userStats = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)",
                responseType: [UserStatsDBResponse].self
            )
            
            // Fetch game sessions
            let gameSessions = try await supabase.performRequest(
                method: "GET",
                path: "game_sessions?user_id=eq.\(userId)&order=created_at.desc",
                responseType: [GameSessionDBResponse].self
            )
            
            // Fetch achievements
            let achievements = try await supabase.performRequest(
                method: "GET",
                path: "user_achievements?user_id=eq.\(userId)",
                responseType: [UserAchievementDBResponse].self
            )
            
            // Create comprehensive export data
            let exportData: [String: Any] = [
                "export_date": ISO8601DateFormatter().string(from: Date()),
                "user_id": userId,
                "username": supabase.user?.userMetadata.username ?? "Unknown",
                "email": supabase.user?.email ?? "Unknown",
                "user_statistics": userStats.first?.toExportDictionary() ?? [:],
                "game_sessions": gameSessions.map { $0.toExportDictionary() },
                "achievements": achievements.map { $0.toExportDictionary() },
                "total_game_sessions": gameSessions.count,
                "account_created": "Unknown", // This would need to be tracked separately
                "data_export_version": "1.0"
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
            
        } catch {
            errorMessage = "Failed to export user data: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Update user's privacy preferences
    func updatePrivacySettings(_ settings: PrivacySettings) async throws {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            // Store privacy settings in Supabase
            let privacyData: [String: Any] = [
                "user_id": userId,
                "share_stats": settings.shareStats,
                "show_on_leaderboard": settings.showOnLeaderboard,
                "allow_friend_requests": settings.allowFriendRequests,
                "data_processing_consent": settings.dataProcessingConsent,
                "marketing_emails": settings.marketingEmails,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            // Use upsert operation (insert or update)
            try await supabase.performVoidRequest(
                method: "POST",
                path: "user_privacy_settings",
                body: privacyData,
                headers: ["Prefer": "resolution=merge-duplicates"]
            )
            
            // Also store locally for offline access
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            UserDefaults.standard.set(data, forKey: "privacy_settings")
            
        } catch {
            errorMessage = "Failed to update privacy settings: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Load user's privacy preferences
    func loadPrivacySettings() async -> PrivacySettings {
        guard let userId = supabase.user?.id else {
            // Return local settings if not authenticated
            return loadLocalPrivacySettings()
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            let response = try await supabase.performRequest(
                method: "GET",
                path: "user_privacy_settings?user_id=eq.\(userId)",
                responseType: [PrivacySettingsDBResponse].self
            )
            
            if let privacyResponse = response.first {
                let settings = PrivacySettings(
                    shareStats: privacyResponse.shareStats,
                    showOnLeaderboard: privacyResponse.showOnLeaderboard,
                    allowFriendRequests: privacyResponse.allowFriendRequests,
                    dataProcessingConsent: privacyResponse.dataProcessingConsent,
                    marketingEmails: privacyResponse.marketingEmails
                )
                
                // Cache locally
                if let data = try? JSONEncoder().encode(settings) {
                    UserDefaults.standard.set(data, forKey: "privacy_settings")
                }
                
                return settings
            } else {
                // No remote settings found, use defaults and create them
                let defaultSettings = PrivacySettings.default
                try? await updatePrivacySettings(defaultSettings)
                return defaultSettings
            }
            
        } catch {
            errorMessage = "Failed to load privacy settings: \(error.localizedDescription)"
            // Return local settings as fallback
            return loadLocalPrivacySettings()
        }
    }
    
    private func loadLocalPrivacySettings() -> PrivacySettings {
        guard let data = UserDefaults.standard.data(forKey: "privacy_settings"),
              let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) else {
            return PrivacySettings.default
        }
        return settings
    }
    
    /// Delete all user account data
    func deleteAccount() async throws {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            // Delete all user data from Supabase in order (respecting foreign key constraints)
            
            // 1. Delete user achievements
            try await supabase.performVoidRequest(
                method: "DELETE",
                path: "user_achievements?user_id=eq.\(userId)",
                body: [:]
            )
            
            // 2. Delete game sessions
            try await supabase.performVoidRequest(
                method: "DELETE",
                path: "game_sessions?user_id=eq.\(userId)",
                body: [:]
            )
            
            // 3. Delete privacy settings
            try await supabase.performVoidRequest(
                method: "DELETE",
                path: "user_privacy_settings?user_id=eq.\(userId)",
                body: [:]
            )
            
            // 4. Delete user stats
            try await supabase.performVoidRequest(
                method: "DELETE",
                path: "user_stats?id=eq.\(userId)",
                body: [:]
            )
            
            // 5. Delete the user account from Supabase Auth
            // Note: This requires admin privileges, typically handled by a server-side function
            // For now, we'll sign out the user and clear local data
            
            // Clear all local data
            let domain = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            
            // Sign out the user
            try await supabase.signOut()
            
            print("Account deletion completed - user signed out and local data cleared")
            
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Get user data summary for account management
    func getUserDataSummary() async throws -> UserDataSummary {
        guard let userId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        isLoading = true
        errorMessage = ""
        
        defer { isLoading = false }
        
        do {
            // Fetch user stats and use them for more accurate data
            let userStats = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId)&select=total_games,created_at",
                responseType: [UserStatsDBResponse].self
            )
            
            let gameSessionsCount = try await supabase.performRequest(
                method: "GET",
                path: "game_sessions?user_id=eq.\(userId)&select=id",
                responseType: [[String: Int]].self
            )
            
            let achievementsCount = try await supabase.performRequest(
                method: "GET",
                path: "user_achievements?user_id=eq.\(userId)&select=achievement_id",
                responseType: [[String: String]].self
            )
            
            return UserDataSummary(
                totalGameSessions: userStats.first?.totalGames ?? gameSessionsCount.count,
                totalAchievements: achievementsCount.count,
                accountCreated: Date(), // This would need to be tracked properly
                lastActivity: Date() // This would need to be tracked properly
            )
            
        } catch {
            errorMessage = "Failed to get user data summary: \(error.localizedDescription)"
            throw error
        }
    }
}

// MARK: - Supporting Models

struct UserDataSummary {
    let totalGameSessions: Int
    let totalAchievements: Int
    let accountCreated: Date
    let lastActivity: Date
}

struct PrivacySettingsDBResponse: Codable {
    let userId: String
    let shareStats: Bool
    let showOnLeaderboard: Bool
    let allowFriendRequests: Bool
    let dataProcessingConsent: Bool
    let marketingEmails: Bool
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case shareStats = "share_stats"
        case showOnLeaderboard = "show_on_leaderboard"
        case allowFriendRequests = "allow_friend_requests"
        case dataProcessingConsent = "data_processing_consent"
        case marketingEmails = "marketing_emails"
        case updatedAt = "updated_at"
    }
}

// MARK: - Extensions for Export

extension UserStatsDBResponse {
    func toExportDictionary() -> [String: Any] {
        return [
            "total_games": totalGames,
            "best_score": bestScore,
            "best_streak": bestStreak,
            "average_score": averageScore,
            "total_correct": totalCorrect,
            "total_questions": totalQuestions
        ]
    }
}

extension GameSessionDBResponse {
    func toExportDictionary() -> [String: Any] {
        return [
            "score": score,
            "streak": streak,
            "correct_answers": correctAnswers,
            "total_questions": totalQuestions,
            "game_type": gameType,
            "created_at": createdAt
        ]
    }
}

extension UserAchievementDBResponse {
    func toExportDictionary() -> [String: Any] {
        return [
            "achievement_id": achievementId,
            "unlocked_at": unlockedAt
        ]
    }
}
