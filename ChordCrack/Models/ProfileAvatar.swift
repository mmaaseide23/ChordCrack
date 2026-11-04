import Foundation

/// Stable storage IDs are kept when artwork evolves. No URLs or uploads.
enum ProfileAvatar: String, CaseIterable, Identifiable {
    case initial, guitar, keys, headphones, note, wave, bolt, star, sparkle
    var id: String { rawValue }
    init(storedID: String?) { self = storedID.flatMap(Self.init(rawValue:)) ?? .initial }
    var title: String {
        switch self {
        case .initial: return "Your initial"
        case .guitar: return "Riff Fox"
        case .keys: return "Key Cat"
        case .headphones: return "Beat Bunny"
        case .note: return "Melody Bird"
        case .wave: return "Wave Buddy"
        case .bolt: return "Bolt Bot"
        case .star: return "Star Pal"
        case .sparkle: return "Cosmic Moth"
        }
    }
    var personality: String {
        switch self {
        case .initial: return "Classic. Completely you."
        case .guitar: return "Tiny paws. Big riffs."
        case .keys: return "Always lands on the right key."
        case .headphones: return "All ears for a good beat."
        case .note: return "A melody with a little mischief."
        case .wave: return "Just here for the good vibrations."
        case .bolt: return "Powered by one more song."
        case .star: return "Born for the encore."
        case .sparkle: return "Follows the music after dark."
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
