import Foundation
import SwiftUI
import Combine

/// Social data belongs to one signed-in account and one request generation.
@MainActor
class SocialManager: ObservableObject {
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var friends: [SocialFriend] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let socialAPI = SocialAPIService()
    private let supabase = SupabaseClient.shared
    private var authObservation: AnyCancellable?
    private var refreshTask: Task<Void, Never>?
    private var refreshID = UUID()
    private var accountID: String?
    private var accountRevision = UUID()
    private var requests: [Section: UUID] = [:]

    private enum Section { case leaderboard, friends, requests }
    private struct AccountScope: Equatable {
        let id: String
        let revision: UUID
    }

    init() {
        // SupabaseClient publishes identity changes on MainActor. Observe them
        // synchronously: even A → signed out → A invalidates A's old requests.
        authObservation = supabase.$isAuthenticated
            .combineLatest(supabase.$user.map { $0?.id.lowercased() })
            .map { authenticated, id in authenticated ? id : nil }
            .removeDuplicates()
            .sink { [weak self] id in self?.updateAccount(id) }
    }

    deinit { refreshTask?.cancel() }

    private var currentAccountID: String? {
        supabase.isAuthenticated ? supabase.user?.id.lowercased() : nil
    }

    private func updateAccount(_ id: String?) {
        guard accountID != id else { return }
        accountID = id
        accountRevision = UUID()
        refreshTask?.cancel()
        refreshTask = nil
        refreshID = UUID()
        requests.removeAll()
        leaderboardEntries = []
        friends = []
        friendRequests = []
        errorMessage = ""
        isLoading = false
    }

    private func beginScope() -> AccountScope? {
        updateAccount(currentAccountID)
        guard let accountID else { return nil }
        return AccountScope(id: accountID, revision: accountRevision)
    }

    private func isCurrent(_ scope: AccountScope) -> Bool {
        updateAccount(currentAccountID)
        return !Task.isCancelled && accountID == scope.id && accountRevision == scope.revision
    }

    // MARK: - Loading

    func loadSocialData() {
        guard let scope = beginScope() else { return }
        refreshTask?.cancel()
        let id = UUID()
        refreshID = id
        isLoading = true
        errorMessage = ""
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.refreshID == id {
                    self.isLoading = false
                    self.refreshTask = nil
                }
            }
            guard self.isCurrent(scope) else { return }
            await self.loadLeaderboard()
            guard self.isCurrent(scope) else { return }
            await self.loadFriends()
            guard self.isCurrent(scope) else { return }
            await self.loadFriendRequests()
        }
    }

    func refreshData() { loadSocialData() }

    private func load<Value>(
        _ section: Section,
        failure: String,
        request: () async throws -> Value,
        apply: (Value) -> Void
    ) async {
        guard let scope = beginScope() else { return }
        let id = UUID()
        requests[section] = id
        do {
            let value = try await request()
            guard isCurrent(scope), requests[section] == id else { return }
            apply(value)
        } catch {
            guard isCurrent(scope), requests[section] == id else { return }
            // Failed privacy/authorization reads must not leave old data visible.
            switch section {
            case .leaderboard: leaderboardEntries = []
            case .friends: friends = []
            case .requests: friendRequests = []
            }
            errorMessage = failure
        }
    }

    func loadLeaderboard() async {
        await load(.leaderboard, failure: "Failed to load leaderboard", request: {
            try await self.socialAPI.getLeaderboard()
        }, apply: { self.leaderboardEntries = $0 })
    }

    func loadFriends() async {
        await load(.friends, failure: "Failed to load friends", request: {
            try await self.socialAPI.getFriends()
        }, apply: { self.friends = $0 })
    }

    func loadFriendRequests() async {
        await load(.requests, failure: "Failed to load friend requests", request: {
            try await self.socialAPI.getFriendRequests()
        }, apply: { self.friendRequests = $0 })
    }

    // MARK: - Friend actions

    func sendFriendRequest(to username: String) async -> Bool {
        guard let scope = beginScope() else {
            errorMessage = "Please sign in to send friend requests"
            return false
        }
        do {
            try await socialAPI.sendFriendRequest(to: username)
            guard isCurrent(scope) else { return false }
            await loadFriendRequests()
            return isCurrent(scope)
        } catch {
            guard isCurrent(scope) else { return false }
            switch error {
            case SocialError.friendshipAlreadyExists:
                errorMessage = "You are already friends with this user"
            case SocialError.friendRequestPending:
                errorMessage = "Friend request already pending with this user"
            case SocialError.userNotFound:
                errorMessage = "User not found - check the username and try again"
            case SocialError.invalidRequest:
                errorMessage = "Cannot send friend request to yourself"
            case SocialError.friendRequestsNotAllowed:
                errorMessage = "This user is not accepting friend requests"
            case APIError.notAuthenticated:
                errorMessage = "Please sign in to send friend requests"
            default:
                errorMessage = "Failed to send friend request - please try again"
            }
            return false
        }
    }

    func respondToFriendRequest(_ request: FriendRequest, accept: Bool) async {
        guard let scope = beginScope() else { return }
        do {
            try await socialAPI.respondToFriendRequest(requestId: request.id, accept: accept)
            guard isCurrent(scope) else { return }
            await loadFriends()
            guard isCurrent(scope) else { return }
            await loadFriendRequests()
        } catch {
            guard isCurrent(scope) else { return }
            errorMessage = accept ? "Failed to accept friend request" : "Failed to decline friend request"
        }
    }

    func removeFriend(_ friend: SocialFriend) async {
        guard let scope = beginScope() else { return }
        do {
            try await socialAPI.removeFriend(friendId: friend.id)
            guard isCurrent(scope) else { return }
            await loadFriends()
        } catch {
            guard isCurrent(scope) else { return }
            errorMessage = "Failed to remove friend"
        }
    }

    func clearError() { errorMessage = "" }
}
