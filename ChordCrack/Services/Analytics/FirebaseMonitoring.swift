import Foundation
import FirebaseCrashlytics
import FirebasePerformance

/// Diagnostics use the same saved choice as Analytics, without account identifiers or custom logs.
@MainActor
enum FirebaseMonitoring {
    private static var isConfigured = false
    private static var isEnabled = false
    private static var revision = 0
    private static let reportPermissionKey = "firebase_diagnostics_previous_session_allowed"

    static var isIsolated: Bool {
        #if DEBUG
        let process = ProcessInfo.processInfo
        return process.arguments.contains("--design-demo") ||
            process.environment["XCTestConfigurationFilePath"] != nil ||
            process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        return false
        #endif
    }

    /// Performance instrumentation must be configured before FirebaseApp.configure().
    static func prepareForLaunch(enabled: Bool) {
        guard !isIsolated else { return }
        Performance.sharedInstance().isInstrumentationEnabled = enabled
        Performance.sharedInstance().isDataCollectionEnabled = enabled
    }

    static func start(enabled: Bool) {
        guard !isIsolated else { return }
        isConfigured = true
        isEnabled = enabled
        revision += 1
        // Keep automatic uploads disabled: the SDK's automatic opt-out only takes
        // effect next launch. We gate queued reports ourselves using the current choice.
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        // A reset or opt-out invalidates the entire previous session's queue,
        // including reports recorded after deleteUnsentReports() was called.
        let previousSessionAllowed = UserDefaults.standard.bool(forKey: reportPermissionKey)
        UserDefaults.standard.set(enabled, forKey: reportPermissionKey)
        if enabled && previousSessionAllowed { sendPendingReportsIfAllowed() }
        else { Crashlytics.crashlytics().deleteUnsentReports() }
    }

    static func setEnabled(_ enabled: Bool) {
        guard !isIsolated, isConfigured else { return }
        revision += 1
        isEnabled = enabled
        Performance.sharedInstance().isDataCollectionEnabled = enabled
        // The instrumentation setting itself applies on the next app launch;
        // dataCollectionEnabled prevents upload immediately while opted out.
        Performance.sharedInstance().isInstrumentationEnabled = enabled
        if !enabled {
            UserDefaults.standard.set(false, forKey: reportPermissionKey)
            Crashlytics.crashlytics().deleteUnsentReports()
        }
        // Enabling does not send an old queue collected while disabled.
        // Reports from the enabled session are considered on the next launch.
    }

    static func resetLocalData() {
        guard !isIsolated, isConfigured else { return }
        revision += 1 // Invalidate a pending check before clearing its queue.
        UserDefaults.standard.set(false, forKey: reportPermissionKey)
        Crashlytics.crashlytics().deleteUnsentReports()
        // Firebase Performance has no public per-event local reset API.
        // This does not claim to delete diagnostics already sent to Firebase.
    }

    private static func sendPendingReportsIfAllowed() {
        let expectedRevision = revision
        Crashlytics.crashlytics().checkForUnsentReports { hasReports in
            Task { @MainActor in
                guard !isIsolated, isEnabled, revision == expectedRevision, hasReports else { return }
                Crashlytics.crashlytics().sendUnsentReports()
            }
        }
    }
}
