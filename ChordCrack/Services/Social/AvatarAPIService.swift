import Foundation

struct AvatarAPIService: AvatarServicing {
    private let supabase = SupabaseClient.shared
    private var currentUserID: String? {
        guard supabase.isAuthenticated else { return nil }
        return supabase.user.flatMap { UUID(uuidString: $0.id)?.uuidString.lowercased() }
    }
    func load(userIDs: [String]) async throws -> [String: ProfileAvatar] {
        guard !DesignDemo.isEnabled, let owner = currentUserID else { throw APIError.notAuthenticated }
        // Bounded, UUID-only filters. Server RLS decides which requested profiles are visible.
        let ids = Array(Set(userIDs.compactMap { UUID(uuidString: $0)?.uuidString.lowercased() })).sorted()
        guard ids.count <= 100 else { throw APIError.invalidResponse }
        guard !ids.isEmpty else { return [:] }
        let rows = try await supabase.performRequest(method: "GET",
            path: "profile_avatars?user_id=in.(\(ids.joined(separator: ",")))&select=user_id,avatar_id",
            responseType: [ProfileAvatarRecord].self)
        guard currentUserID == owner, !Task.isCancelled else { throw APIError.notAuthenticated }
        var avatars: [String: ProfileAvatar] = [:]
        for row in rows where ids.contains(row.userID.lowercased()) {
            avatars[row.userID.lowercased()] = ProfileAvatar(storedID: row.avatarID)
        }
        return avatars
    }
    func save(_ avatar: ProfileAvatar, for expectedUserID: String) async throws -> ProfileAvatar {
        guard !DesignDemo.isEnabled, let owner = currentUserID,
              owner == expectedUserID.lowercased(), !Task.isCancelled else { throw APIError.notAuthenticated }
        let rows = try await supabase.performRequest(method: "POST", path: "rpc/set_profile_avatar",
            body: ["p_avatar_id": avatar.rawValue, "p_expected_user_id": owner],
            responseType: [ProfileAvatarRecord].self)
        guard currentUserID == owner, !Task.isCancelled else { throw APIError.notAuthenticated }
        guard rows.count == 1, rows[0].userID.lowercased() == owner,
              rows[0].avatarID == avatar.rawValue else { throw APIError.invalidResponse }
        return avatar
    }
}
