import Foundation

class ConfigManager {
    static let shared = ConfigManager()

    private let config: [String: Any]?

    private init() {
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) as? [String: Any] {
            self.config = plist
        } else {
            self.config = nil
            debugLog("[ConfigManager] Config.plist not found. Please create Config.plist with your Supabase credentials.")
        }
    }

    var isConfigured: Bool {
        return config != nil && config?["SUPABASE_URL"] != nil && config?["SUPABASE_ANON_KEY"] != nil
    }

    var supabaseURL: String {
        guard let url = config?["SUPABASE_URL"] as? String, !url.isEmpty else {
            debugLog("[ConfigManager] SUPABASE_URL not found in Config.plist")
            return ""
        }
        return url
    }

    var supabaseAnonKey: String {
        guard let key = config?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            debugLog("[ConfigManager] SUPABASE_ANON_KEY not found in Config.plist")
            return ""
        }
        return key
    }

    var privacyPolicyURL: String {
        return config?["PRIVACY_POLICY_URL"] as? String ?? "https://chordcrack.app/privacy"
    }

    var termsOfServiceURL: String {
        return config?["TERMS_OF_SERVICE_URL"] as? String ?? "https://chordcrack.app/terms"
    }

    var supportEmail: String {
        return config?["SUPPORT_EMAIL"] as? String ?? "support@chordcrack.app"
    }
}
