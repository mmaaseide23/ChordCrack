import SwiftUI
import FirebaseCore
import FirebaseAnalytics

@main
struct ChordCrackApp: App {
    
    init() {
        guard !FirebaseMonitoring.isIsolated else { return }
        let collectionEnabled = FirebaseAnalyticsManager.collectionPreference()
        FirebaseMonitoring.prepareForLaunch(enabled: collectionEnabled)

        // Configure Firebase
        FirebaseApp.configure()
        
        // Set analytics collection based on user preference
        Analytics.setAnalyticsCollectionEnabled(collectionEnabled)
        FirebaseMonitoring.start(enabled: collectionEnabled)
        
        // Disable ad personalization; this does not control advertising ID collection.
        Analytics.setUserProperty("false", forName: "allow_ad_personalization_signals")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
