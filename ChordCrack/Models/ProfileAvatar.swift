import Foundation

/// Stable allowlist, mirrored by the database CHECK constraint. No URLs or uploads.
enum ProfileAvatar: String, CaseIterable, Identifiable {
    case initial, guitar, keys, headphones, note, wave, bolt, star, sparkle
    var id: String { rawValue }
    init(storedID: String?) { self = storedID.flatMap(Self.init(rawValue:)) ?? .initial }
    var title: String {
        switch self {
        case .initial: return "Your initial"
        case .guitar: return "Guitar"
        case .keys: return "Keys"
        case .headphones: return "Headphones"
        case .note: return "Melody"
        case .wave: return "Wave"
        case .bolt: return "Lightning"
        case .star: return "Star"
        case .sparkle: return "Spark"
        }
    }
    var symbol: String? {
        switch self {
        case .initial: return nil
        case .guitar: return "guitars.fill"
        case .keys: return "pianokeys"
        case .headphones: return "headphones"
        case .note: return "music.note"
        case .wave: return "waveform"
        case .bolt: return "bolt.fill"
        case .star: return "star.fill"
        case .sparkle: return "sparkles"
        }
    }
    static func initial(for username: String) -> String {
        String(username.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }
}

struct ProfileAvatarRecord: Decodable {
    let userID: String
    let avatarID: String
    enum CodingKeys: String, CodingKey { case userID = "user_id", avatarID = "avatar_id" }
}

protocol AvatarServicing {
    func load(userIDs: [String]) async throws -> [String: ProfileAvatar]
    func save(_ avatar: ProfileAvatar, for expectedUserID: String) async throws -> ProfileAvatar
}
