import Foundation
import SwiftUI

// MARK: - Social Friend Model

struct SocialFriend: Identifiable {
    let id: String // User ID
    let username: String
    let status: UserStatus
    let lastSeen: Date
    let bestScore: Int
    
    var statusText: String {
        switch status {
        case .online: return "Online now"
        case .offline: return "Last seen \(timeAgo)"
        case .playing: return "Playing now"
        }
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

// MARK: - Challenge Model

struct SocialChallenge: Identifiable {
    let id: String
    let challengerId: String
    let challenger: String
    let opponentId: String
    let opponent: String
    let type: SocialChallengeType
    let status: ChallengeStatus
    let challengerScore: Int
    let opponentScore: Int
    let challengerCompleted: Bool
    let opponentCompleted: Bool
    let createdAt: Date
    let expiresAt: Date?
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            return "\(minutes/60)h ago"
        }
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var winner: String? {
        guard status == .completed else { return nil }
        
        if challengerScore > opponentScore {
            return challenger
        } else if opponentScore > challengerScore {
            return opponent
        } else {
            return "Tie"
        }
    }
}

enum SocialChallengeType: String, CaseIterable {
    case dailyChallenge = "dailyChallenge"
    case speedRound = "speedRound"
    case mixedMode = "mixedMode"
    case chordProgression = "chordProgression"
    
    var displayName: String {
        switch self {
        case .dailyChallenge: return "Daily Challenge"
        case .speedRound: return "Speed Round"
        case .mixedMode: return "Mixed Mode"
        case .chordProgression: return "Chord Progression"
        }
    }
    
    var color: Color {
        switch self {
        case .dailyChallenge: return ColorTheme.primaryGreen
        case .speedRound: return Color.orange
        case .mixedMode: return Color.purple
        case .chordProgression: return Color.blue
        }
    }
    
    var gameTypeConstant: String {
        switch self {
        case .dailyChallenge: return GameTypeConstants.dailyChallenge
        case .speedRound: return GameTypeConstants.speedRound
        case .mixedMode: return GameTypeConstants.mixedPractice
        case .chordProgression: return GameTypeConstants.chordProgressions
        }
    }
}

enum ChallengeStatus: String {
    case pending = "pending"
    case active = "active"
    case completed = "completed"
    case declined = "declined"
    case expired = "expired"
    
    var backgroundColor: Color {
        switch self {
        case .pending: return Color.orange.opacity(0.2)
        case .active: return ColorTheme.primaryGreen.opacity(0.2)
        case .completed: return Color.blue.opacity(0.2)
        case .declined: return ColorTheme.error.opacity(0.2)
        case .expired: return Color.gray.opacity(0.2)
        }
    }
    
    var textColor: Color {
        switch self {
        case .pending: return Color.orange
        case .active: return ColorTheme.primaryGreen
        case .completed: return Color.blue
        case .declined: return ColorTheme.error
        case .expired: return Color.gray
        }
    }
}
