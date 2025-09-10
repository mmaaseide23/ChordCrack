import Foundation

/// Social API Service for managing friends, challenges, and leaderboards
class SocialAPIService {
    private let supabase = SupabaseClient.shared
    
    // MARK: - Leaderboard
    
    func getLeaderboard() async throws -> [LeaderboardEntry] {
        let response = try await supabase.performRequest(
            method: "GET",
            path: "leaderboard?select=*",
            responseType: [LeaderboardDBResponse].self
        )
        
        return response.map { entry in
            LeaderboardEntry(
                rank: entry.rank,
                username: entry.username,
                bestScore: entry.bestScore,
                totalGames: entry.totalGames
            )
        }
    }
    
    // MARK: - Friends Management
    
    func getFriends() async throws -> [SocialFriend] {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // Get accepted friends
        let friendsResponse = try await supabase.performRequest(
            method: "GET",
            path: "friend_requests?or=(user_id.eq.\(currentUserId),friend_id.eq.\(currentUserId))&status=eq.accepted&select=*",
            responseType: [FriendRequestDBResponse].self
        )
        
        // Convert to SocialFriend objects
        var friends: [SocialFriend] = []
        
        for friendRequest in friendsResponse {
            let friendUsername: String
            let friendUserId: String
            
            // Determine which user is the friend (not the current user)
            if friendRequest.userId == currentUserId {
                friendUsername = friendRequest.recipientUsername
                friendUserId = friendRequest.friendId
            } else {
                friendUsername = friendRequest.requesterUsername
                friendUserId = friendRequest.userId
            }
            
            // Get friend's stats for best score
            do {
                let statsResponse = try await supabase.performRequest(
                    method: "GET",
                    path: "user_stats?id=eq.\(friendUserId)&select=best_score",
                    responseType: [UserStatsBestScoreResponse].self
                )
                
                let bestScore = statsResponse.first?.bestScore ?? 0
                
                let friend = SocialFriend(
                    id: friendUserId,
                    username: friendUsername,
                    status: .offline, // Default status - would need presence system for real status
                    lastSeen: Date().addingTimeInterval(-Double.random(in: 0...86400)), // Mock last seen
                    bestScore: bestScore
                )
                
                friends.append(friend)
            } catch {
                // If we can't get stats, still add friend with default values
                let friend = SocialFriend(
                    id: friendUserId,
                    username: friendUsername,
                    status: .offline,
                    lastSeen: Date().addingTimeInterval(-3600),
                    bestScore: 0
                )
                friends.append(friend)
            }
        }
        
        return friends
    }
    
    func getFriendRequests() async throws -> [FriendRequest] {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // Get pending friend requests received by current user
        let response = try await supabase.performRequest(
            method: "GET",
            path: "friend_requests?friend_id=eq.\(currentUserId)&status=eq.pending&select=*",
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
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // First, find the user by username
        let userResponse = try await supabase.performRequest(
            method: "GET",
            path: "user_stats?username=eq.\(username)&select=id",
            responseType: [UserIdResponse].self
        )
        
        guard let targetUser = userResponse.first else {
            throw APIError.invalidResponse // User not found
        }
        
        // Check if friendship already exists
        let existingResponse = try await supabase.performRequest(
            method: "GET",
            path: "friends?or=(and(user_id.eq.\(currentUserId),friend_id.eq.\(targetUser.id)),and(user_id.eq.\(targetUser.id),friend_id.eq.\(currentUserId)))&select=id",
            responseType: [BasicIdResponse].self
        )
        
        if !existingResponse.isEmpty {
            throw SocialError.friendshipAlreadyExists
        }
        
        // Create friend request
        let requestData: [String: Any] = [
            "user_id": currentUserId,
            "friend_id": targetUser.id,
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
        
        try await supabase.performVoidRequest(
            method: "DELETE",
            path: "friends?or=(and(user_id.eq.\(currentUserId),friend_id.eq.\(friendId)),and(user_id.eq.\(friendId),friend_id.eq.\(currentUserId)))",
            body: [:]
        )
    }
    
    // MARK: - Challenges
    
    func getChallenges() async throws -> [SocialChallenge] {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        let response = try await supabase.performRequest(
            method: "GET",
            path: "challenges_with_users?or=(challenger_id.eq.\(currentUserId),opponent_id.eq.\(currentUserId))&status=neq.completed&order=created_at.desc",
            responseType: [ChallengeDBResponse].self
        )
        
        return response.compactMap { challengeDB in
            guard let challengeType = SocialChallengeType(rawValue: challengeDB.challengeType),
                  let status = ChallengeStatus(rawValue: challengeDB.status),
                  let createdAt = ISO8601DateFormatter().date(from: challengeDB.createdAt) else {
                return nil
            }
            
            return SocialChallenge(
                id: challengeDB.id,
                challengerId: challengeDB.challengerId,
                challenger: challengeDB.challengerUsername,
                opponentId: challengeDB.opponentId,
                opponent: challengeDB.opponentUsername,
                type: challengeType,
                status: status,
                challengerScore: challengeDB.challengerScore,
                opponentScore: challengeDB.opponentScore,
                challengerCompleted: challengeDB.challengerCompleted,
                opponentCompleted: challengeDB.opponentCompleted,
                createdAt: createdAt,
                expiresAt: ISO8601DateFormatter().date(from: challengeDB.expiresAt)
            )
        }
    }
    
    func sendChallenge(to friendId: String, type: SocialChallengeType) async throws {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        let challengeData: [String: Any] = [
            "challenger_id": currentUserId,
            "opponent_id": friendId,
            "challenge_type": type.rawValue,
            "status": "pending"
        ]
        
        try await supabase.performVoidRequest(
            method: "POST",
            path: "challenges",
            body: challengeData
        )
    }
    
    func respondToChallenge(challengeId: String, accept: Bool) async throws {
        let newStatus = accept ? "active" : "declined"
        
        let updateData: [String: Any] = [
            "status": newStatus,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase.performVoidRequest(
            method: "PATCH",
            path: "challenges?id=eq.\(challengeId)",
            body: updateData
        )
        
        // If declined, we keep the challenge for history but mark as declined
    }
    
    func submitChallengeScore(challengeId: String, score: Int, correctAnswers: Int, totalQuestions: Int) async throws {
        guard let currentUserId = supabase.user?.id else {
            throw APIError.notAuthenticated
        }
        
        // First get the challenge to determine which player is submitting
        let challengeResponse = try await supabase.performRequest(
            method: "GET",
            path: "challenges?id=eq.\(challengeId)&select=challenger_id,opponent_id,challenger_completed,opponent_completed",
            responseType: [ChallengeScoreResponse].self
        )
        
        guard let challenge = challengeResponse.first else {
            throw APIError.invalidResponse
        }
        
        let isChallenger = challenge.challengerId == currentUserId
        
        var updateData: [String: Any] = [
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if isChallenger {
            updateData["challenger_score"] = score
            updateData["challenger_completed"] = true
        } else {
            updateData["opponent_score"] = score
            updateData["opponent_completed"] = true
        }
        
        // Check if both players have completed
        let bothCompleted = (isChallenger ? true : challenge.challengerCompleted) &&
                           (!isChallenger ? true : challenge.opponentCompleted)
        
        if bothCompleted {
            updateData["status"] = "completed"
        }
        
        try await supabase.performVoidRequest(
            method: "PATCH",
            path: "challenges?id=eq.\(challengeId)",
            body: updateData
        )
    }
}

// MARK: - Supporting Models

struct LeaderboardDBResponse: Codable {
    let rank: Int
    let username: String
    let bestScore: Int
    let totalGames: Int
    
    enum CodingKeys: String, CodingKey {
        case rank
        case username
        case bestScore = "best_score"
        case totalGames = "total_games"
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

struct ChallengeDBResponse: Codable {
    let id: String
    let challengerId: String
    let opponentId: String
    let challengeType: String
    let status: String
    let challengerScore: Int
    let opponentScore: Int
    let challengerCompleted: Bool
    let opponentCompleted: Bool
    let createdAt: String
    let expiresAt: String
    let challengerUsername: String
    let opponentUsername: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengerId = "challenger_id"
        case opponentId = "opponent_id"
        case challengeType = "challenge_type"
        case status
        case challengerScore = "challenger_score"
        case opponentScore = "opponent_score"
        case challengerCompleted = "challenger_completed"
        case opponentCompleted = "opponent_completed"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case challengerUsername = "challenger_username"
        case opponentUsername = "opponent_username"
    }
}

struct UserStatsBestScoreResponse: Codable {
    let bestScore: Int
    
    enum CodingKeys: String, CodingKey {
        case bestScore = "best_score"
    }
}

struct UserIdResponse: Codable {
    let id: String
}

struct BasicIdResponse: Codable {
    let id: String
}

struct ChallengeScoreResponse: Codable {
    let challengerId: String
    let opponentId: String
    let challengerCompleted: Bool
    let opponentCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case challengerId = "challenger_id"
        case opponentId = "opponent_id"
        case challengerCompleted = "challenger_completed"
        case opponentCompleted = "opponent_completed"
    }
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
    case challengeNotFound
    case invalidChallengeState
    case invalidRequest
    
    var errorDescription: String? {
        switch self {
        case .friendshipAlreadyExists:
            return "You are already friends with this user"
        case .friendRequestPending:
            return "Friend request already pending"
        case .userNotFound:
            return "User not found"
        case .challengeNotFound:
            return "Challenge not found"
        case .invalidChallengeState:
            return "Invalid challenge state"
        case .invalidRequest:
            return "Invalid request"
        }
    }
}
