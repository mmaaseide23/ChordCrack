@main
struct SocialAudit {
    @MainActor static func main() async {
        var results: [[String: String]] = []
        let backend = SupabaseClient.shared
        let api = SocialAPIService()
        func run(_ name: String, _ operation: () async throws -> Void) async {
            backend.reset(); signInFixture()
            do { try await operation(); results.append(["test":name,"status":"passed"]) }
            catch let failure as AuditFailure { results.append(["test":name,"status":"failed","detail":failure.message]) }
            catch { results.append(["test":name,"status":"failed","detail":String(describing:error)]) }
        }
        await run("signed_out_friend_operations_rejected") {
            backend.user = nil; backend.isAuthenticated = false
            var rejected = 0
            do { _ = try await api.getFriends() } catch APIError.notAuthenticated { rejected += 1 }
            do { _ = try await api.getFriendRequests() } catch APIError.notAuthenticated { rejected += 1 }
            do { try await api.sendFriendRequest(to:"FixtureB") } catch APIError.notAuthenticated { rejected += 1 }
            do { try await api.removeFriend(friendId:auditB) } catch APIError.notAuthenticated { rejected += 1 }
            try require(rejected == 4 && backend.calls.isEmpty, "Unauthenticated friend operations reached transport")
        }
        await run("self_request_case_insensitive_rejected") {
            try await expectSocialError(.invalidRequest) { try await api.sendFriendRequest(to:"fIxTuReA") }
            try require(backend.calls.isEmpty, "Self request reached transport")
        }
        await run("unknown_user_rejected") {
            backend.handler = { _ in json("[]") }
            try await expectSocialError(.userNotFound) { try await api.sendFriendRequest(to:"UnknownFixture") }
            try require(backend.calls.count == 1, "Unexpected mutation")
        }
        func configureRequest(_ existing: String = "[]", allows: Bool = true) {
            backend.handler = { call in
                if call.path.hasPrefix("social_profiles?") { return json("[{\"id\":\"\(auditB)\"}]") }
                if call.path.hasPrefix("user_privacy_settings?") { return json("[{\"allow_friend_requests\":\(allows)}]") }
                return json(existing)
            }
        }
        await run("username_lookup_uses_names_only_directory") {
            backend.handler = { call in
                try require(call.path.hasPrefix("social_profiles?username=eq.") && call.path.hasSuffix("&select=id"), "Lookup attempted to read private statistics")
                return json("[]")
            }
            try await expectSocialError(.userNotFound) { try await api.sendFriendRequest(to:"PrivateFixture") }
        }
        await run("recipient_disabled_requests_rejected") {
            configureRequest(allows:false)
            try await expectSocialError(.friendRequestsNotAllowed) { try await api.sendFriendRequest(to:"FixtureB") }
            try require(backend.calls.allSatisfy { $0.method == "GET" }, "Privacy refusal still wrote request")
        }
        await run("duplicate_friend_rejected") {
            configureRequest("[{\"id\":\"relation1\",\"status\":\"accepted\"}]")
            try await expectSocialError(.friendshipAlreadyExists) { try await api.sendFriendRequest(to:"FixtureB") }
        }
        await run("duplicate_pending_request_rejected") {
            configureRequest("[{\"id\":\"relation1\",\"status\":\"pending\"}]")
            try await expectSocialError(.friendRequestPending) { try await api.sendFriendRequest(to:"FixtureB") }
        }
        await run("new_request_lowercases_both_ids_and_sets_pending") {
            configureRequest()
            try await api.sendFriendRequest(to:"FixtureB")
            guard let call = backend.calls.last else { throw AuditFailure(message:"No request") }
            try require(call.method == "POST" && call.path == "friends", "Wrong mutation")
            try require(call.body?["user_id"] as? String == auditA.lowercased(), "Requester ID casing")
            try require(call.body?["friend_id"] as? String == auditB.lowercased(), "Recipient ID casing")
            try require(call.body?["status"] as? String == "pending", "Wrong initial status")
        }
        await run("accept_request_patches_accepted") {
            backend.handler = { _ in json("[]") }
            try await api.respondToFriendRequest(requestId:"synthetic-relation",accept:true)
            try require(backend.calls.count == 1 && backend.calls[0].method == "PATCH", "Wrong accept requests")
            try require(backend.calls[0].body?["status"] as? String == "accepted", "Wrong accepted status")
        }
        await run("decline_request_patches_then_deletes") {
            backend.handler = { _ in json("[]") }
            try await api.respondToFriendRequest(requestId:"synthetic-relation",accept:false)
            try require(backend.calls.map(\.method) == ["PATCH","DELETE"], "Wrong decline sequence")
            try require(backend.calls[0].body?["status"] as? String == "declined", "Wrong declined status")
        }
        await run("remove_friend_matches_both_directions") {
            backend.handler = { _ in json("[]") }
            try await api.removeFriend(friendId:auditB)
            let call = backend.calls[0]
            try require(call.method == "DELETE", "Wrong remove method")
            try require(call.path.contains("user_id.eq.\(auditA.lowercased()),friend_id.eq.\(auditB.lowercased())") && call.path.contains("user_id.eq.\(auditB.lowercased()),friend_id.eq.\(auditA.lowercased())"), "Incomplete relationship scope")
        }
        await run("friends_deduplicate_ignore_self_and_unrelated_rows") {
            let rows = [relation("1",auditA,auditB),relation("2",auditB.lowercased(),auditA.lowercased(),fromName:"FixtureB",toName:"FixtureA"),relation("3",auditA,auditA),relation("4",auditB,auditC)]
            backend.handler = { call in
                if call.path.hasPrefix("friends_with_usernames?") { return json("[" + rows.joined(separator:",") + "]") }
                if call.path.hasPrefix("user_privacy_settings?") { return json("[{\"share_stats\":true}]") }
                return json(statsB)
            }
            let friends = try await api.getFriends()
            try require(friends.count == 1 && friends[0].id.lowercased() == auditB.lowercased(), "Incorrect friend set")
            try require(friends[0].bestScore == 90, "Stats mapping failed")
        }
        await run("private_friend_stats_do_not_fetch_stats") {
            backend.handler = { call in
                if call.path.hasPrefix("friends_with_usernames?") { return json("[" + relation("1",auditA,auditB) + "]") }
                if call.path.hasPrefix("user_privacy_settings?") { return json("[{\"share_stats\":false}]") }
                throw AuditFailure(message:"Private stats fetched")
            }
            let friends = try await api.getFriends()
            try require(friends.count == 1 && friends[0].bestScore == 0, "Wrong hidden-stats fallback")
            try require(!backend.calls.contains { $0.path.hasPrefix("user_stats?") }, "Private stats request issued")
        }
        await run("received_requests_filter_current_recipient_and_pending") {
            backend.handler = { call in
                try require(call.path.contains("friend_id=eq.\(auditA.lowercased())&status=eq.pending"), "Missing recipient/status scope")
                return json("[" + relation("1",auditB,auditA,status:"pending",fromName:"FixtureB",toName:"FixtureA") + "]")
            }
            let requests = try await api.getFriendRequests()
            try require(requests.count == 1 && requests[0].fromUsername == "FixtureB" && requests[0].status == .pending, "Request mapping failed")
        }
        await run("leaderboard_hides_opted_out_and_reranks") {
            backend.handler = { call in call.path.hasPrefix("user_privacy_settings?") ? json("[{\"user_id\":\"\(auditB.lowercased())\",\"show_on_leaderboard\":false},{\"user_id\":\"\(auditC.uppercased())\",\"show_on_leaderboard\":true}]") : json(board) }
            let entries = try await api.getLeaderboard()
            try require(entries.count == 1 && entries[0].username == "VisibleFixture" && entries[0].rank == 1, "Privacy filtering/reranking failed")
        }
        await run("leaderboard_privacy_failure_does_not_show_unknown_consent") {
            backend.handler = { call in
                if call.path.hasPrefix("user_privacy_settings?") { throw APIError.networkError }
                return json(board)
            }
            do {
                let entries = try await api.getLeaderboard()
                try require(entries.isEmpty, "Privacy fetch failure returned both fixture users, including HiddenFixture (fail-open client behavior; server policy unverified)")
            } catch is APIError { /* Failing the load safely is acceptable. */ }
        }
        await run("recipient_refusal_has_specific_ui_message") {
            configureRequest(allows:false)
            let manager = SocialManager()
            let succeeded = await manager.sendFriendRequest(to:"FixtureB")
            try require(!succeeded, "Refused request reported success")
            try require(manager.errorMessage == "This user is not accepting friend requests", "UI instead reports: \(manager.errorMessage)")
        }
        await run("social_manager_clears_stale_friends_after_logout_refresh") {
            let manager = SocialManager()
            manager.friends = [SocialFriend(id:auditB,username:"OldAccountFriend",status:.offline,lastSeen:Date(),bestScore:1,bestStreak:1,totalGames:1,totalCorrect:1,totalQuestions:1,averageScore:1)]
            backend.user = nil; backend.isAuthenticated = false
            await manager.loadFriends()
            try require(manager.friends.isEmpty, "Prior account's friend array remains after unauthenticated refresh (view lifetime determines visible exposure)")
        }
        await run("inflight_friend_response_discarded_after_account_switch") {
            let manager = SocialManager()
            backend.handler = { call in
                if call.path.hasPrefix("friends_with_usernames?") {
                    signInFixture(auditC,name:"FixtureC")
                    return json("[" + relation("1",auditA,auditB) + "]")
                }
                if call.path.hasPrefix("user_privacy_settings?") { return json("[{\"share_stats\":false}]") }
                return json(statsB)
            }
            await manager.loadFriends()
            try require(manager.friends.isEmpty, "A's in-flight friend result was published after current user changed to C")
        }
        await run("privacy_cache_is_scoped_to_current_account") {
            backend.handler = { _ in json("[{\"user_id\":\"\(auditA)\",\"share_stats\":false,\"show_on_leaderboard\":false,\"allow_friend_requests\":false,\"data_processing_consent\":true,\"marketing_emails\":false,\"updated_at\":\"2026-01-01T00:00:00Z\"}]") }
            let a = await AccountManagementService.shared.loadPrivacySettings()
            try require(!a.shareStats, "Fixture privacy did not load")
            signInFixture(auditB,name:"FixtureB")
            backend.handler = { _ in throw APIError.networkError }
            let b = await AccountManagementService.shared.loadPrivacySettings()
            try require(b.shareStats == PrivacySettings.default.shareStats, "A's preferences leaked to B")
        }
        await run("privacy_read_without_existing_row_attempts_default_creation") {
            backend.handler = { _ in json("[]") }
            _ = await AccountManagementService.shared.loadPrivacySettings()
            try require(backend.calls.contains { $0.method == "POST" && $0.path == "user_privacy_settings" }, "Expected existing implementation's auto-create behavior changed")
        }
        await run("demo_account_operations_reject_before_transport") {
            DesignDemo.isEnabled = true
            do { _ = try await AccountManagementService.shared.exportUserData(); throw AuditFailure(message:"Demo export allowed") } catch APIError.notAuthenticated {}
            do { try await AccountManagementService.shared.updatePrivacySettings(.default); throw AuditFailure(message:"Demo settings update allowed") } catch APIError.notAuthenticated {}
            try require(backend.calls.isEmpty, "Demo account method reached transport")
        }
        await run("leaderboard_missing_preferences_hide_unknown_consent") {
            backend.handler = { call in call.path.hasPrefix("user_privacy_settings?") ? json("[]") : json(board) }
            let entries = try await api.getLeaderboard()
            try require(entries.isEmpty, "Missing privacy rows displayed leaderboard entries")
        }
        await run("missing_friend_stats_permission_does_not_fetch_stats") {
            backend.handler = { call in
                if call.path.hasPrefix("friends_with_usernames?") { return json("[" + relation("1",auditA,auditB) + "]") }
                if call.path.hasPrefix("user_privacy_settings?") { return json("[]") }
                throw AuditFailure(message:"Stats requested without permission")
            }
            _ = try await api.getFriends()
            try require(!backend.calls.contains { $0.path.hasPrefix("user_stats?") }, "Missing preference allowed stats read")
        }
        await run("missing_recipient_preferences_prevent_request") {
            backend.handler = { call in call.path.hasPrefix("social_profiles?") ? json("[{\"id\":\"\(auditB)\"}]") : json("[]") }
            try await expectSocialError(.friendRequestsNotAllowed) { try await api.sendFriendRequest(to:"FixtureB") }
            try require(backend.calls.allSatisfy { $0.method == "GET" }, "Request written without permission")
        }
        await run("logout_clears_all_social_state_without_refresh") {
            let manager = SocialManager()
            manager.leaderboardEntries = [LeaderboardEntry(rank:1,username:"Old",bestScore:1,totalGames:1)]
            manager.friends = [SocialFriend(id:auditB,username:"Old",status:.offline,lastSeen:Date(),bestScore:1,bestStreak:1,totalGames:1,totalCorrect:1,totalQuestions:1,averageScore:1)]
            manager.friendRequests = [FriendRequest(id:"old",fromUserId:auditB,fromUsername:"Old",toUserId:auditA,toUsername:"FixtureA",status:.pending,createdAt:Date())]
            manager.isLoading = true; manager.errorMessage = "Old error"
            backend.isAuthenticated = false
            try require(manager.friends.isEmpty && manager.friendRequests.isEmpty && manager.leaderboardEntries.isEmpty, "Logout did not clear all collections immediately")
            try require(!manager.isLoading && manager.errorMessage.isEmpty, "Logout retained progress/error state")
        }
        await run("account_switch_clears_all_social_state_without_refresh") {
            let manager = SocialManager()
            manager.leaderboardEntries = [LeaderboardEntry(rank:1,username:"Old",bestScore:1,totalGames:1)]
            manager.friendRequests = [FriendRequest(id:"old",fromUserId:auditB,fromUsername:"Old",toUserId:auditA,toUsername:"FixtureA",status:.pending,createdAt:Date())]
            signInFixture(auditC,name:"FixtureC")
            try require(manager.friendRequests.isEmpty && manager.leaderboardEntries.isEmpty, "Account switch retained old collections")
        }
        await run("old_response_discarded_after_logout_and_same_account_login") {
            let manager = SocialManager()
            backend.handler = { call in
                if call.path.hasPrefix("friends_with_usernames?") {
                    backend.isAuthenticated = false; backend.user = nil
                    signInFixture()
                    return json("[" + relation("1",auditA,auditB) + "]")
                }
                return json("[{\"share_stats\":false}]")
            }
            await manager.loadFriends()
            try require(manager.friends.isEmpty, "Old request survived logout and same-account re-login")
        }
        await run("old_error_discarded_after_account_switch") {
            let manager = SocialManager()
            backend.handler = { _ in
                signInFixture(auditC,name:"FixtureC")
                throw APIError.networkError
            }
            await manager.loadFriendRequests()
            try require(manager.errorMessage.isEmpty, "Prior account error surfaced in new account")
        }
        await run("failed_privacy_refresh_clears_cached_leaderboard") {
            let manager = SocialManager()
            manager.leaderboardEntries = [LeaderboardEntry(rank:1,username:"CachedFixture",bestScore:1,totalGames:1)]
            backend.handler = { _ in throw APIError.networkError }
            await manager.loadLeaderboard()
            try require(manager.leaderboardEntries.isEmpty, "Cached entries survived failed privacy read")
            try require(!manager.errorMessage.isEmpty, "Failed read provided no feedback")
            try require(backend.calls.count == 1 && backend.calls[0].path.hasPrefix("user_privacy_settings?"), "Fetched leaderboard after failed privacy read")
        }
        await run("newer_same_account_refresh_wins_over_slow_old_response") {
            let manager = SocialManager()
            var firstResponse: CheckedContinuation<Data,Never>?
            var friendsReads = 0
            backend.handler = { call in
                if call.path.hasPrefix("friends_with_usernames?") {
                    friendsReads += 1
                    if friendsReads == 1 { return await withCheckedContinuation { firstResponse = $0 } }
                    return json("[" + relation("new",auditA,auditC,toName:"NewFixture") + "]")
                }
                return json("[{\"share_stats\":false}]")
            }
            let old = Task { await manager.loadFriends() }
            while firstResponse == nil { await Task.yield() }
            await manager.loadFriends()
            firstResponse?.resume(returning:json("[" + relation("old",auditA,auditB) + "]"))
            await old.value
            try require(manager.friends.count == 1 && manager.friends[0].id == auditC, "Slow old response replaced newer result")
        }
        await run("cancelled_load_does_not_publish_result") {
            let manager = SocialManager()
            var pending: CheckedContinuation<Data,Never>?
            backend.handler = { call in
                if call.path.hasPrefix("friends_with_usernames?") { return await withCheckedContinuation { pending = $0 } }
                return json("[{\"share_stats\":false}]")
            }
            let task = Task { await manager.loadFriends() }
            while pending == nil { await Task.yield() }
            task.cancel()
            pending?.resume(returning:json("[" + relation("old",auditA,auditB) + "]"))
            await task.value
            try require(manager.friends.isEmpty, "Cancelled load published result")
        }
        await run("late_friend_action_failure_does_not_affect_new_account") {
            let manager = SocialManager()
            backend.handler = { _ in
                signInFixture(auditC,name:"FixtureC")
                throw SocialError.friendRequestPending
            }
            let success = await manager.sendFriendRequest(to:"FixtureB")
            try require(!success && manager.errorMessage.isEmpty, "Late action updated new account state")
        }
        let output: [String: Any] = ["scope":"Actual unchanged SocialAPIService, SocialManager, AccountManagementService and models compiled against in-memory transport and preferences; not real sign-in/RLS/UI validation", "network_requests":0,"real_records_read_or_written":0,"audio":false,"passed":results.filter { $0["status"] == "passed" }.count,"failed":results.filter { $0["status"] == "failed" }.count,"tests":results]
        let data = try! JSONSerialization.data(withJSONObject:output, options:[.prettyPrinted,.sortedKeys])
        print(String(decoding:data,as:UTF8.self))
    }
}
