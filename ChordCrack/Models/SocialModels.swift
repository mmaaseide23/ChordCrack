import Foundation
import SwiftUI

// MARK: - Enhanced Social Friend Model with Full Stats

struct SocialFriend: Identifiable {
    let id: String // User ID
    let username: String
    let status: UserStatus
    let lastSeen: Date
    let bestScore: Int
    let bestStreak: Int
    let totalGames: Int
    let totalCorrect: Int
    let totalQuestions: Int
    let averageScore: Double
    
    var statusText: String {
        switch status {
        case .online: return "Online now"
        case .offline: return "Last seen \(timeAgo)"
        case .playing: return "Playing now"
        }
    }
    
    var accuracy: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalQuestions) * 100
    }
    
    var level: Int {
        // Calculate level based on total games and average score
        let xp = (totalGames * 100) + Int(averageScore * 10)
        return max(1, xp / 1000)
    }
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(lastSeen)
        let hours = Int(interval / 3600)
        if hours < 1 {
            return "recently"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            return "\(hours/24)d ago"
        }
    }
}

enum UserStatus {
    case online
    case offline
    case playing
    
    var color: Color {
        switch self {
        case .online: return Color.green
        case .offline: return Color.gray
        case .playing: return Color.orange
        }
    }
}

// MARK: - Friend Request Model

struct FriendRequest: Identifiable {
    let id: String
    let fromUserId: String
    let fromUsername: String
    let toUserId: String
    let toUsername: String
    let status: FriendRequestStatus
    let createdAt: Date
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            return "\(minutes/60)h ago"
        }
    }
}

enum FriendRequestStatus: String, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

// NOTE: Removed all Challenge-related models as they're no longer needed
