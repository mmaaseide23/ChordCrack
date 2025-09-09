// PrivacySettings.swift

import Foundation

struct PrivacySettings: Codable {
    var shareStats: Bool = true
    var showOnLeaderboard: Bool = true
    var allowFriendRequests: Bool = true
    var dataProcessingConsent: Bool = true
    var marketingEmails: Bool = false
    
    static let `default` = PrivacySettings()
}
