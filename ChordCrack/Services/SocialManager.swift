import Foundation
import SwiftUI

/// Social Manager for handling friends, challenges, and leaderboards
@MainActor
class SocialManager: ObservableObject {
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var friends: [SocialFriend] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var challenges: [SocialChallenge] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let socialAPI = SocialAPIService()
    
    // MARK: - Public Methods
    
    func loadSocialData() {
        Task {
            isLoading = true
            errorMessage = ""
            
            await loadLeaderboard()
            await loadFriends()
            await loadFriendRequests()
            await loadChallenges()
            
            isLoading = false
        }
    }
    
    func refreshData() {
        loadSocialData()
    }
    
    // MARK: - Leaderboard
    
    func loadLeaderboard() async {
        do {
            let entries = try await socialAPI.getLeaderboard()
            self.leaderboardEntries = entries
        } catch {
            self.errorMessage = "Failed to load leaderboard"
            print("Leaderboard error: \(error)")
        }
    }
    
    // MARK: - Friends Management
    
    func loadFriends() async {
        do {
            let friendsList = try await socialAPI.getFriends()
            self.friends = friendsList
        } catch {
            self.errorMessage = "Failed to load friends"
            print("Friends error: \(error)")
        }
    }
    
    func loadFriendRequests() async {
        do {
            let requests = try await socialAPI.getFriendRequests()
            self.friendRequests = requests
        } catch {
            self.errorMessage = "Failed to load friend requests"
            print("Friend requests error: \(error)")
        }
    }
    
    func sendFriendRequest(to username: String) async -> Bool {
        do {
            try await socialAPI.sendFriendRequest(to: username)
            await loadFriendRequests() // Refresh requests
            return true
        } catch SocialError.friendshipAlreadyExists {
            errorMessage = "You are already friends with this user"
            return false
        } catch SocialError.friendRequestPending {
            errorMessage = "Friend request already pending with this user"
            return false
        } catch SocialError.userNotFound {
            errorMessage = "User not found - check the username and try again"
            return false
        } catch SocialError.invalidRequest {
            errorMessage = "Cannot send friend request to yourself"
            return false
        } catch APIError.notAuthenticated {
            errorMessage = "Please sign in to send friend requests"
            return false
        } catch {
            errorMessage = "Failed to send friend request - please try again"
            print("Friend request error: \(error)")
            return false
        }
    }
    
    func respondToFriendRequest(_ request: FriendRequest, accept: Bool) async {
        do {
            try await socialAPI.respondToFriendRequest(requestId: request.id, accept: accept)
            
            // Refresh both friends and requests
            await loadFriends()
            await loadFriendRequests()
        } catch {
            errorMessage = accept ? "Failed to accept friend request" : "Failed to decline friend request"
            print("Friend request response error: \(error)")
        }
    }
    
    func removeFriend(_ friend: SocialFriend) async {
        do {
            try await socialAPI.removeFriend(friendId: friend.id)
            await loadFriends() // Refresh friends list
        } catch {
            errorMessage = "Failed to remove friend"
            print("Remove friend error: \(error)")
        }
    }
    
    // MARK: - Challenges
    
    func loadChallenges() async {
        do {
            let challengesList = try await socialAPI.getChallenges()
            self.challenges = challengesList
        } catch {
            self.errorMessage = "Failed to load challenges"
            print("Challenges error: \(error)")
        }
    }
    
    func sendChallenge(to friend: SocialFriend, type: SocialChallengeType) async -> Bool {
        do {
            try await socialAPI.sendChallenge(to: friend.id, type: type)
            await loadChallenges() // Refresh challenges
            return true
        } catch {
            errorMessage = "Failed to send challenge"
            print("Send challenge error: \(error)")
            return false
        }
    }
    
    func respondToChallenge(_ challenge: SocialChallenge, accept: Bool) async {
        do {
            try await socialAPI.respondToChallenge(challengeId: challenge.id, accept: accept)
            await loadChallenges() // Refresh challenges
        } catch {
            errorMessage = accept ? "Failed to accept challenge" : "Failed to decline challenge"
            print("Challenge response error: \(error)")
        }
    }
    
    func submitChallengeScore(challengeId: String, score: Int, correctAnswers: Int, totalQuestions: Int) async -> Bool {
        do {
            try await socialAPI.submitChallengeScore(
                challengeId: challengeId,
                score: score,
                correctAnswers: correctAnswers,
                totalQuestions: totalQuestions
            )
            await loadChallenges() // Refresh challenges to show updated status
            return true
        } catch {
            errorMessage = "Failed to submit challenge score"
            print("Submit challenge score error: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = ""
    }
    
    func getCurrentUserChallenges() -> [SocialChallenge] {
        // This would need the current user ID - you might want to pass this in or get it from UserDataManager
        return challenges
    }
    
    func getPendingReceivedChallenges(for userId: String) -> [SocialChallenge] {
        return challenges.filter { challenge in
            challenge.opponentId == userId && challenge.status == .pending
        }
    }
    
    func getActiveChallenges(for userId: String) -> [SocialChallenge] {
        return challenges.filter { challenge in
            (challenge.challengerId == userId || challenge.opponentId == userId) &&
            challenge.status == .active
        }
    }
}
