import SwiftUI
import FirebaseCore
import FirebaseAnalytics

@main
struct ChordCrackApp: App {
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Set analytics collection based on user preference
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Disable advertising ID collection for privacy
        Analytics.setUserProperty("false", forName: "allow_ad_personalization_signals")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
