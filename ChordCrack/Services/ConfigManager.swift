import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    
    private let config: [String: Any]
    
    private init() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Config.plist file not found. Please create Config.plist with your Supabase credentials.")
        }
        self.config = plist
    }
    
    var supabaseURL: String {
        guard let url = config["SUPABASE_URL"] as? String else {
            fatalError("SUPABASE_URL not found in Config.plist")
        }
        return url
    }
    
    var supabaseAnonKey: String {
        guard let key = config["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Config.plist")
        }
        return key
    }
    
    var privacyPolicyURL: String {
        return config["PRIVACY_POLICY_URL"] as? String ?? "https://chordcrack.app/privacy"
    }
    
    var termsOfServiceURL: String {
        return config["TERMS_OF_SERVICE_URL"] as? String ?? "https://chordcrack.app/terms"
    }
    
    var supportEmail: String {
        return config["SUPPORT_EMAIL"] as? String ?? "support@chordcrack.app"
    }
}
