@MainActor final class AvatarFixtureService: AvatarServicing {
    var loads = 0, saves = 0
    var loadHandler: ([String]) async throws -> [String: ProfileAvatar] = { _ in [:] }
    var saveHandler: (ProfileAvatar, String) async throws -> ProfileAvatar = { avatar, _ in avatar }
    func load(userIDs: [String]) async throws -> [String: ProfileAvatar] { loads += 1; return try await loadHandler(userIDs) }
    func save(_ avatar: ProfileAvatar, for id: String) async throws -> ProfileAvatar { saves += 1; return try await saveHandler(avatar,id) }
}
@MainActor func settled(_ condition: () -> Bool) async throws {
    for _ in 0..<500 { if condition() { return }; try await Task.sleep(for: .milliseconds(2)) }
    throw AuditFailure(message:"State did not settle")
}
func avatarRow(_ id: String, _ avatar: String) -> String { "{\"user_id\":\"\(id)\",\"avatar_id\":\"\(avatar)\"}" }

@main struct AvatarChecks {
    @MainActor static func main() async throws {
        var results: [[String:String]] = []
        let backend = SupabaseClient.shared, api = AvatarAPIService()
        func run(_ name: String, _ body: () async throws -> Void) async {
            backend.reset(); signInFixture()
            do { try await body(); results.append(["test":name,"status":"passed"]) }
            catch { results.append(["test":name,"status":"failed","detail":String(describing:error)]) }
        }
        await run("curated catalog and unknown/missing IDs use safe initial fallback") {
            try require(ProfileAvatar.allCases.count == 9 && Set(ProfileAvatar.allCases.map(\.rawValue)).count == 9,"Catalog duplicate")
            try require(ProfileAvatar(storedID:nil) == .initial && ProfileAvatar(storedID:"future") == .initial && ProfileAvatar(storedID:"https://example.invalid/a") == .initial,"Untrusted ID accepted")
            try require(ProfileAvatar.initial(for:"  alex ") == "A" && ProfileAvatar.initial(for:"").isEmpty,"Initial fallback incorrect")
        }
        await run("reads use UUID-only narrow projection and discard unsolicited rows") {
            backend.handler = { call in
                try require(call.path == "profile_avatars?user_id=in.(\(auditB.lowercased()))&select=user_id,avatar_id" && call.method == "GET","Unsafe or broad query")
                return json("["+avatarRow(auditB,"keys")+","+avatarRow(auditC,"star")+"]")
            }
            let result = try await api.load(userIDs:[auditB,auditB.lowercased(),"x)&select=*"])
            try require(result == [auditB.lowercased():.keys],"Unsolicited row used")
        }
        await run("anonymous, preview and oversized requests never reach transport") {
            backend.isAuthenticated = false
            do { _ = try await api.load(userIDs:[auditA]); throw AuditFailure(message:"Anonymous read allowed") } catch APIError.notAuthenticated {}
            signInFixture(); DesignDemo.isEnabled = true
            do { _ = try await api.save(.star,for:auditA); throw AuditFailure(message:"Preview wrote") } catch APIError.notAuthenticated {}
            DesignDemo.isEnabled = false
            do { _ = try await api.load(userIDs:(0..<101).map { _ in UUID().uuidString }); throw AuditFailure(message:"Unbounded read allowed") } catch APIError.invalidResponse {}
            try require(backend.calls.isEmpty,"Invalid request reached transport")
        }
        await run("save binds authenticated owner and confirms returned choice") {
            backend.handler = { call in
                try require(call.method == "POST" && call.path == "rpc/set_profile_avatar","Wrong write endpoint")
                try require(call.body?.count == 2 && call.body?["p_avatar_id"] as? String == "star" && call.body?["p_expected_user_id"] as? String == auditA.lowercased(),"Unscoped write")
                return json("["+avatarRow(auditA,"star")+"]")
            }
            let saved = try await api.save(.star,for:auditA)
            try require(saved == .star,"Confirmed save lost")
            do { _ = try await api.save(.star,for:auditB); throw AuditFailure(message:"Wrong owner save accepted") } catch APIError.notAuthenticated {}
            try require(backend.calls.count == 1,"Wrong owner reached server")
        }
        await run("mismatched save response is never reported successful") {
            for response in ["[]","["+avatarRow(auditB,"star")+"]","["+avatarRow(auditA,"guitar")+"]"] {
                backend.handler = { _ in json(response) }
                do { _ = try await api.save(.star,for:auditA); throw AuditFailure(message:"Wrong response accepted") } catch APIError.invalidResponse {}
            }
        }
        await run("identity change during API read discards result") {
            backend.handler = { _ in signInFixture(auditC); return json("["+avatarRow(auditB,"star")+"]") }
            do { _ = try await api.load(userIDs:[auditB]); throw AuditFailure(message:"Cross-account result accepted") } catch APIError.notAuthenticated {}
        }
        await run("own selection loads, saves and reloads from confirmed server state") {
            let service = AvatarFixtureService()
            var saved: ProfileAvatar = .guitar
            service.loadHandler = { ids in [ids[0].lowercased():saved] }
            service.saveHandler = { choice, id in try require(id == auditA.lowercased(),"Owner changed"); saved = choice; return choice }
            let store = ProfileAvatarStore(service:service,observeAuthentication:false)
            store.setAccount(auditA.lowercased()); try await settled { !store.isLoading && service.loads == 1 }
            try require(store.avatar == .guitar,"Existing avatar missing")
            let success = await store.save(.keys)
            try require(success && store.avatar == .keys,"Save not reflected")
            await store.refresh(); try require(store.avatar == .keys && service.loads == 2,"Saved choice not reloaded")
        }
        await run("save failure retains confirmed avatar and allows retry") {
            let service = AvatarFixtureService()
            service.loadHandler = { ids in [ids[0].lowercased():.guitar] }
            service.saveHandler = { _,_ in throw APIError.networkError }
            let store = ProfileAvatarStore(service:service,observeAuthentication:false)
            store.setAccount(auditA); try await settled { service.loads == 1 && !store.isLoading }
            let failed = await store.save(.star)
            try require(!failed && store.avatar == .guitar && !store.isSaving && store.errorMessage != nil,"Failure changed confirmed avatar, claimed success or stuck")
            service.saveHandler = { avatar,_ in avatar }
            let retried = await store.save(.star)
            try require(retried && store.avatar == .star && store.errorMessage == nil,"Retry failed")
        }
        await run("preview changes are in-memory only") {
            let service = AvatarFixtureService(), store = ProfileAvatarStore(service:AvatarFixtureService(),preview:true)
            let isolated = ProfileAvatarStore(service:service,preview:true)
            await isolated.refresh()
            let success = await isolated.save(.headphones)
            try require(success && isolated.avatar == .headphones && store.avatar == .initial && service.loads == 0 && service.saves == 0 && backend.calls.isEmpty,"Preview touched backend or persisted")
        }
        await run("new-account load failure never retains previous avatar") {
            let service = AvatarFixtureService()
            service.loadHandler = { ids in
                if service.loads == 1 { return [ids[0]:.guitar] }
                throw APIError.networkError
            }
            let store = ProfileAvatarStore(service:service,observeAuthentication:false)
            store.setAccount(auditA.lowercased()); try await settled { store.avatar == .guitar }
            store.setAccount(auditB.lowercased())
            try require(store.avatar == .initial,"Previous account avatar visible during new load")
            try await settled { service.loads == 2 && !store.isLoading }
            try require(store.avatar == .initial && store.errorMessage != nil && store.canEdit,"Failed new-account load retained data or disabled retries")
        }
        await run("sign-out and same-account re-login discard stale reads") {
            let service = AvatarFixtureService()
            var first: CheckedContinuation<[String:ProfileAvatar],Error>?
            service.loadHandler = { ids in
                if service.loads == 1 { return try await withCheckedThrowingContinuation { first = $0 } }
                return [ids[0]:.keys]
            }
            let store = ProfileAvatarStore(service:service,observeAuthentication:false)
            store.setAccount(auditA.lowercased()); try await settled { first != nil }
            store.setAccount(nil); try require(store.avatar == .initial && !store.canEdit,"Signed-out avatar retained")
            store.setAccount(auditA.lowercased()); try await settled { store.avatar == .keys }
            first!.resume(returning:[auditA.lowercased():.guitar])
            try await Task.sleep(for:.milliseconds(10))
            try require(store.avatar == .keys && !store.isLoading,"Old login overwrote new one")
        }
        await run("late save cannot overwrite new account") {
            let service = AvatarFixtureService()
            var pending: CheckedContinuation<ProfileAvatar,Error>?
            service.loadHandler = { ids in [ids[0]:.keys] }
            service.saveHandler = { _,id in try require(id == auditA.lowercased(),"Wrong owner"); return try await withCheckedThrowingContinuation { pending = $0 } }
            let store = ProfileAvatarStore(service:service,observeAuthentication:false)
            store.setAccount(auditA.lowercased()); try await settled { service.loads == 1 && !store.isLoading }
            let task = Task { await store.save(.star) }; try await settled { pending != nil }
            store.setAccount(auditC.lowercased()); try await settled { service.loads == 2 && !store.isLoading }
            pending!.resume(returning:.star)
            let success = await task.value
            try require(!success && store.avatar == .keys && !store.isSaving && store.errorMessage == nil,"Late save affected new account")
        }
        await run("cancelled save releases busy state without applying result") {
            let service = AvatarFixtureService()
            var pending: CheckedContinuation<ProfileAvatar,Error>?
            service.saveHandler = { _,_ in try await withCheckedThrowingContinuation { pending = $0 } }
            let store = ProfileAvatarStore(service:service,observeAuthentication:false)
            store.setAccount(auditA); try await settled { service.loads == 1 && !store.isLoading }
            let task = Task { await store.save(.star) }; try await settled { pending != nil }
            task.cancel(); pending!.resume(returning:.star)
            let success = await task.value
            try require(!success && !store.isSaving && store.avatar == .initial,"Cancelled save applied or stuck")
        }
        await run("auth observer clears own state synchronously") {
            let service = AvatarFixtureService(); service.loadHandler = { ids in [ids[0]:.wave] }
            let store = ProfileAvatarStore(service:service)
            try await settled { store.avatar == .wave }
            backend.isAuthenticated = false
            try require(store.avatar == .initial && !store.canEdit,"Sign-out did not invalidate immediately")
        }
        await run("leaderboard avatars preserve visibility filtering and reranking") {
            backend.handler = { call in
                if call.path.hasPrefix("user_privacy_settings?") { return json("[{\"user_id\":\"\(auditC)\",\"show_on_leaderboard\":true}]") }
                if call.path.hasPrefix("profile_avatars?") {
                    try require(!call.path.contains(auditB.lowercased()),"Requested hidden leaderboard profile")
                    return json("["+avatarRow(auditC,"note")+"]")
                }
                return json(board)
            }
            let entries = try await SocialAPIService().getLeaderboard()
            try require(entries.count == 1 && entries[0].rank == 1 && entries[0].avatarID == "note","Avatar lost or hidden entry exposed")
        }
        await run("missing migration falls back without breaking social listing") {
            backend.handler = { call in
                if call.path.hasPrefix("user_privacy_settings?") { return json("[{\"user_id\":\"\(auditC)\",\"show_on_leaderboard\":true}]") }
                if call.path.hasPrefix("profile_avatars?") { throw APIError.networkError }
                return json(board)
            }
            let entries = try await SocialAPIService().getLeaderboard()
            try require(entries.count == 1 && entries[0].avatarID == nil,"Avatar error broke listing")
        }
        await run("friend avatar merge honors missing server-visible rows") {
            for visible in [true,false] {
                backend.handler = { call in
                    if call.path.hasPrefix("friends_with_usernames?") { return json("["+relation("friend",auditA,auditB)+"]") }
                    if call.path.hasPrefix("user_privacy_settings?") { return json("[{\"share_stats\":\(visible)}]") }
                    if call.path.hasPrefix("profile_avatars?") { return json(visible ? "["+avatarRow(auditB,"guitar")+"]" : "[]") }
                    return json(statsB)
                }
                let friends = try await SocialAPIService().getFriends()
                try require(friends.count == 1 && friends[0].username == "FixtureB" && friends[0].avatarID == (visible ? "guitar" : nil),"Friend merge leaked or lost avatar")
            }
        }
        print(String(decoding:try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]),as:UTF8.self))
        if results.contains(where: { $0["status"] == "failed" }) { exit(1) }
        print("PASS: \(results.count) avatar checks; no production, photos or audio.")
    }
}
