import Foundation
import SwiftUI

/// Social Manager for handling friends and leaderboards (No challenges)
@MainActor
class SocialManager: ObservableObject {
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var friends: [SocialFriend] = []
    @Published var friendRequests: [FriendRequest] = []
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
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = ""
    }
}
