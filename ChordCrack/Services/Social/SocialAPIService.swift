import Foundation

/// Social API Service for managing friends and leaderboards (No challenges)
class SocialAPIService {
    private let supabase = SupabaseClient.shared
    
    // MARK: - Leaderboard with Privacy Settings
    
    func getLeaderboard() async throws -> [LeaderboardEntry] {
        // First, get privacy settings to know who should be shown
        let privacySettings = try await getLeaderboardPrivacySettings()
        
        // Get all leaderboard data from the view
        let response = try await supabase.performRequest(
            method: "GET",
            path: "leaderboard?select=*&order=best_score.desc&limit=100",
            responseType: [LeaderboardDBResponse].self
        )
        
        // Filter entries based on privacy settings
        let filteredEntries = response.compactMap { (entry: LeaderboardDBResponse) -> LeaderboardEntry? in
            // Check if user wants to be shown on leaderboard
            // Default to true if no privacy setting found (backwards compatibility)
            let shouldShow = privacySettings[entry.userId] ?? true
            
            guard shouldShow else {
                print("[SocialAPI] User \(entry.username) excluded from leaderboard (privacy settings)")
                return nil
            }
            
            return LeaderboardEntry(
                rank: entry.rank,
                username: entry.username,
                bestScore: entry.bestScore,
                totalGames: entry.totalGames
            )
        }
        
        // Recalculate ranks after filtering
        return filteredEntries.enumerated().map { (index: Int, entry: LeaderboardEntry) -> LeaderboardEntry in
            LeaderboardEntry(
                rank: index + 1,
                username: entry.username,
                bestScore: entry.bestScore,
                totalGames: entry.totalGames
            )
        }
    }
    
    private func getLeaderboardPrivacySettings() async throws -> [String: Bool] {
        var privacySettings: [String: Bool] = [:]
        
        do {
            // Get all privacy settings at once
            let privacyResponse = try await supabase.performRequest(
                method: "GET",
                path: "user_privacy_settings?select=user_id,show_on_leaderboard",
                responseType: [LeaderboardPrivacyResponse].self
            )
            
            // Create a mapping of user_id to show_on_leaderboard setting
            for setting in privacyResponse {
                privacySettings[setting.userId] = setting.showOnLeaderboard
            }
            
            print("[SocialAPI] Loaded privacy settings for \(privacySettings.count) users")
            
        } catch {
            // If privacy settings query fails, default to showing all users
            print("[SocialAPI] Failed to load privacy settings: \(error)")
            // Return empty dictionary so all users are shown by default
            return [:]
        }
        
        return privacySettings
    }
    
    // MARK: - Friends Management (FIXED WITH CASE-INSENSITIVE COMPARISON)
    
    func getFriends() async throws -> [SocialFriend] {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // Normalize current user ID to lowercase for consistent comparison
        let normalizedCurrentUserId = currentUserId.lowercased()
        
        // Get accepted friends using the friends view
        // Use lowercase in the query to match database format
        let friendsResponse = try await supabase.performRequest(
            method: "GET",
            path: "friends_with_usernames?or=(user_id.eq.\(normalizedCurrentUserId),friend_id.eq.\(normalizedCurrentUserId))&status=eq.accepted&select=*",
            responseType: [FriendRequestDBResponse].self
        )
        
        // Convert to SocialFriend objects with full stats
        var friends: [SocialFriend] = []
        var processedFriendIds = Set<String>() // To prevent duplicates
        
        for friendRequest in friendsResponse {
            let friendUsername: String
            let friendUserId: String
            
            // Normalize IDs for comparison (convert to lowercase)
            let normalizedUserId = friendRequest.userId.lowercased()
            let normalizedFriendId = friendRequest.friendId.lowercased()
            
            // Determine which user is the friend based on the current user's position
            if normalizedUserId == normalizedCurrentUserId {
                // Current user is the requester (user_id), so friend is the recipient (friend_id)
                friendUsername = friendRequest.recipientUsername
                friendUserId = friendRequest.friendId // Keep original casing for storage
            } else if normalizedFriendId == normalizedCurrentUserId {
                // Current user is the recipient (friend_id), so friend is the requester (user_id)
                friendUsername = friendRequest.requesterUsername
                friendUserId = friendRequest.userId // Keep original casing for storage
            } else {
                // This shouldn't happen - skip this record
                print("Warning: Friend request doesn't involve current user")
                continue
            }
            
            // Validation: prevent self-friending and duplicates
            if friendUserId.lowercased() == normalizedCurrentUserId {
                print("Error: Detected self-friend relationship for user \(currentUserId)")
                continue
            }
            
            if processedFriendIds.contains(friendUserId.lowercased()) {
                print("Skipping duplicate friend: \(friendUserId)")
                continue
            }
            
            processedFriendIds.insert(friendUserId.lowercased())
            
            // Get friend's full stats - check if they want to share stats
            let friendStats = await getFriendStats(userId: friendUserId, username: friendUsername)
            friends.append(friendStats)
        }
        
        return friends
    }
    
    private func getFriendStats(userId: String, username: String) async -> SocialFriend {
        do {
            // First check if friend wants to share stats
            let privacyResponse = try await supabase.performRequest(
                method: "GET",
                path: "user_privacy_settings?user_id=eq.\(userId.lowercased())&select=share_stats",
                responseType: [FriendPrivacyResponse].self
            )
            
            let shareStats = privacyResponse.first?.shareStats ?? true
            
            if !shareStats {
                // Return friend with hidden stats
                return SocialFriend(
                    id: userId,
                    username: username,
                    status: .offline,
                    lastSeen: Date().addingTimeInterval(-3600),
                    bestScore: 0,
                    bestStreak: 0,
                    totalGames: 0,
                    totalCorrect: 0,
                    totalQuestions: 0,
                    averageScore: 0
                )
            }
            
            // If they share stats, get the actual stats
            let statsResponse = try await supabase.performRequest(
                method: "GET",
                path: "user_stats?id=eq.\(userId.lowercased())&select=*",
                responseType: [UserStatsDBResponse].self
            )
            
            if let stats = statsResponse.first {
                return SocialFriend(
                    id: userId,
                    username: username,
                    status: .offline, // Default status - would need presence system for real status
                    lastSeen: Date().addingTimeInterval(-Double.random(in: 0...86400)), // Mock last seen
                    bestScore: stats.bestScore,
                    bestStreak: stats.bestStreak,
                    totalGames: stats.totalGames,
                    totalCorrect: stats.totalCorrect,
                    totalQuestions: stats.totalQuestions,
                    averageScore: stats.averageScore
                )
            } else {
                // If stats not found, add with default values
                return SocialFriend(
                    id: userId,
                    username: username,
                    status: .offline,
                    lastSeen: Date().addingTimeInterval(-3600),
                    bestScore: 0,
                    bestStreak: 0,
                    totalGames: 0,
                    totalCorrect: 0,
                    totalQuestions: 0,
                    averageScore: 0
                )
            }
        } catch {
            // If we can't get stats, still add friend with default values
            return SocialFriend(
                id: userId,
                username: username,
                status: .offline,
                lastSeen: Date().addingTimeInterval(-3600),
                bestScore: 0,
                bestStreak: 0,
                totalGames: 0,
                totalCorrect: 0,
                totalQuestions: 0,
                averageScore: 0
            )
        }
    }
    
    func getFriendRequests() async throws -> [FriendRequest] {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // Use lowercase for query consistency
        let normalizedCurrentUserId = currentUserId.lowercased()
        
        // Get pending friend requests received by current user using the view
        let response = try await supabase.performRequest(
            method: "GET",
            path: "friends_with_usernames?friend_id=eq.\(normalizedCurrentUserId)&status=eq.pending&select=*",
            responseType: [FriendRequestDBResponse].self
        )
        
        return response.map { request in
            FriendRequest(
                id: request.id,
                fromUserId: request.userId,
                fromUsername: request.requesterUsername,
                toUserId: request.friendId,
                toUsername: request.recipientUsername,
                status: FriendRequestStatus(rawValue: request.status) ?? .pending,
                createdAt: ISO8601DateFormatter().date(from: request.createdAt) ?? Date()
            )
        }
    }
    
    func sendFriendRequest(to username: String) async throws {
        guard let currentUserId = supabase.user?.id,
              let currentUsername = supabase.user?.userMetadata.username else {
            throw APIError.notAuthenticated
        }
        
        // Prevent sending request to self
        if username.lowercased() == currentUsername.lowercased() {
            throw SocialError.invalidRequest
        }
        
        // First, find the user by username
        let userResponse = try await supabase.performRequest(
            method: "GET",
            path: "user_stats?username=eq.\(username)&select=id",
            responseType: [UserIdResponse].self
        )
        
        guard let targetUser = userResponse.first else {
            throw SocialError.userNotFound
        }
        
        // Check if target user allows friend requests
        let privacyResponse = try await supabase.performRequest(
            method: "GET",
            path: "user_privacy_settings?user_id=eq.\(targetUser.id.lowercased())&select=allow_friend_requests",
            responseType: [FriendRequestPrivacyResponse].self
        )
        
        let allowsFriendRequests = privacyResponse.first?.allowFriendRequests ?? true
        
        if !allowsFriendRequests {
            throw SocialError.friendRequestsNotAllowed
        }
        
        // Normalize IDs for comparison
        let normalizedCurrentUserId = currentUserId.lowercased()
        let normalizedTargetUserId = targetUser.id.lowercased()
        
        // Check if friendship or request already exists
        let existingResponse = try await supabase.performRequest(
            method: "GET",
            path: "friends?or=(and(user_id.eq.\(normalizedCurrentUserId),friend_id.eq.\(normalizedTargetUserId)),and(user_id.eq.\(normalizedTargetUserId),friend_id.eq.\(normalizedCurrentUserId)))&select=id,status",
            responseType: [FriendshipCheckResponse].self
        )
        
        if let existing = existingResponse.first {
            if existing.status == "accepted" {
                throw SocialError.friendshipAlreadyExists
            } else if existing.status == "pending" {
                throw SocialError.friendRequestPending
            }
        }
        
        // Create friend request with lowercase IDs for consistency
        let requestData: [String: Any] = [
            "user_id": normalizedCurrentUserId,
            "friend_id": normalizedTargetUserId,
            "status": "pending"
        ]
        
        try await supabase.performVoidRequest(
            method: "POST",
            path: "friends",
            body: requestData
        )
    }
    
    func respondToFriendRequest(requestId: String, accept: Bool) async throws {
        let newStatus = accept ? "accepted" : "declined"
        
        let updateData: [String: Any] = [
            "status": newStatus,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase.performVoidRequest(
            method: "PATCH",
            path: "friends?id=eq.\(requestId)",
            body: updateData
        )
        
        // If declined, delete the request
        if !accept {
            try await supabase.performVoidRequest(
                method: "DELETE",
                path: "friends?id=eq.\(requestId)",
                body: [:]
            )
        }
    }
    
    func removeFriend(friendId: String) async throws {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // Normalize IDs for query
        let normalizedCurrentUserId = currentUserId.lowercased()
        let normalizedFriendId = friendId.lowercased()
        
        try await supabase.performVoidRequest(
            method: "DELETE",
            path: "friends?or=(and(user_id.eq.\(normalizedCurrentUserId),friend_id.eq.\(normalizedFriendId)),and(user_id.eq.\(normalizedFriendId),friend_id.eq.\(normalizedCurrentUserId)))",
            body: [:]
        )
    }
}

// MARK: - Supporting Models

struct LeaderboardDBResponse: Codable {
    let rank: Int
    let username: String
    let bestScore: Int
    let totalGames: Int
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case rank
        case username
        case bestScore = "best_score"
        case totalGames = "total_games"
        case userId = "user_id"
    }
}

struct LeaderboardPrivacyResponse: Codable {
    let userId: String
    let showOnLeaderboard: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case showOnLeaderboard = "show_on_leaderboard"
    }
}

struct FriendPrivacyResponse: Codable {
    let shareStats: Bool
    
    enum CodingKeys: String, CodingKey {
        case shareStats = "share_stats"
    }
}

struct FriendRequestPrivacyResponse: Codable {
    let allowFriendRequests: Bool
    
    enum CodingKeys: String, CodingKey {
        case allowFriendRequests = "allow_friend_requests"
    }
}

struct FriendRequestDBResponse: Codable {
    let id: String
    let userId: String
    let friendId: String
    let status: String
    let createdAt: String
    let updatedAt: String
    let requesterUsername: String
    let recipientUsername: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case requesterUsername = "requester_username"
        case recipientUsername = "recipient_username"
    }
}

struct UserIdResponse: Codable {
    let id: String
}

struct FriendshipCheckResponse: Codable {
    let id: String
    let status: String
}

// MARK: - Social-specific Error Types

enum SocialError: Error, LocalizedError {
    case friendshipAlreadyExists
    case friendRequestPending
    case userNotFound
    case invalidRequest
    case friendRequestsNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .friendshipAlreadyExists:
            return "You are already friends with this user"
        case .friendRequestPending:
            return "Friend request already pending"
        case .userNotFound:
            return "User not found"
        case .invalidRequest:
            return "Invalid request"
        case .friendRequestsNotAllowed:
            return "This user is not accepting friend requests"
        }
    }
}
