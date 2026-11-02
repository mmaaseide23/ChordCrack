extension FirebaseAnalyticsManager {
    static func testingInstance() -> FirebaseAnalyticsManager { FirebaseAnalyticsManager() }
}
@main struct Checks {
    @MainActor static func main() async {
        var passed=0
        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            guard condition() else { fatalError("FAIL: \(name)") }
            passed += 1
        }
        func setup(_ preference: Bool?, previousSessionAllowed: Bool = true) {
            UserDefaults.standard.values = [:]
            UserDefaults.standard.set(preference, forKey: "firebase_analytics_enabled")
            UserDefaults.standard.set(previousSessionAllowed, forKey: "firebase_diagnostics_previous_session_allowed")
            Analytics.clear(); FirebaseApp.configurations=0; DesignDemo.isEnabled=false; Date.clock=0
            FirebaseMonitoring.resetTestState(); Crashlytics.instance.clear()
            ProcessInfo.processInfo.arguments=[]; ProcessInfo.processInfo.environment=[:]
            Performance.instance.isInstrumentationEnabled=false
            Performance.instance.isDataCollectionEnabled=false
        }
        setup(false); bootstrap()
        check("startup never overrides opt-out", Analytics.collections == [false] && FirebaseApp.configurations == 1)
        let off = FirebaseAnalyticsManager.testingInstance()
        off.startSession(); off.trackGameStart(gameType:"synthetic"); off.endSession()
        off.trackScreenView("synthetic"); off.setUserProperties(username:"fixture",totalGames:1,currentLevel:1)
        check("opt-out suppresses events/properties", Analytics.events.isEmpty && Analytics.properties.count == 1 && !off.isAnalyticsEnabled)
        off.resetAnalyticsData()
        check("reset while disabled calls SDK without event", Analytics.resets == 1 && Analytics.events.isEmpty && Analytics.collections.allSatisfy{!$0})
        setup(nil); bootstrap()
        check("existing new-user default retained", Analytics.collections == [true] && UserDefaults.standard.object(forKey:"firebase_analytics_enabled") == nil)
        let on = FirebaseAnalyticsManager.testingInstance()
        check("reserved session_start never logged", Analytics.events.isEmpty)
        Date.clock=60; on.endSession(); on.endSession()
        check("session ends once with actual duration", Analytics.events.count == 1 && Analytics.events[0].0 == "session_end" && Analytics.events[0].1["session_length_seconds"] as? Int == 60)
        on.startSession(); Date.clock=90; on.setAnalyticsEnabled(false)
        check("disable persists preference", UserDefaults.standard.bool(forKey:"firebase_analytics_enabled") == false && Analytics.collections.last == false)
        Date.clock=1000; on.endSession()
        check("disabled timer cannot leak duration", Analytics.events.count == 1)
        on.setAnalyticsEnabled(true); on.setAnalyticsEnabled(true)
        check("enable event only on transition", Analytics.events.filter{$0.0 == "analytics_enabled"}.count == 1)
        Date.clock=1030; on.endSession()
        check("re-enable excludes disabled interval", Analytics.events.last?.1["session_length_seconds"] as? Int == 30)
        let eventCount=Analytics.events.count
        on.resetAnalyticsData(); on.endSession()
        check("reset invalidates timer without telemetry", Analytics.resets == 1 && Analytics.events.count == eventCount)
        setup(false); bootstrap()
        check("next launch respects persisted disabled setting", Analytics.collections == [false])
        if supportsDemo {
            setup(true); DesignDemo.isEnabled=true; bootstrap()
            let demo=FirebaseAnalyticsManager.testingInstance()
            demo.setAnalyticsEnabled(true); demo.resetAnalyticsData(); demo.trackGameStart(gameType:"synthetic")
            check("demo never configures or collects", FirebaseApp.configurations == 0 && Analytics.collections.isEmpty && Analytics.events.isEmpty && Analytics.resets == 0 && !demo.isAnalyticsEnabled)
        }
        setup(false); bootstrap()
        check("opt-out disables Performance and discards unsent crashes", !Performance.instance.isDataCollectionEnabled && !Performance.instance.isInstrumentationEnabled && Crashlytics.instance.deleted == 1 && Crashlytics.instance.checks.isEmpty)
        check("Crashlytics never enables automatic uploads", Crashlytics.instance.automaticChoices == [false])
        setup(true); bootstrap()
        check("opt-in configures Performance", Performance.instance.isDataCollectionEnabled && Performance.instance.isInstrumentationEnabled)
        Crashlytics.instance.checks[0](true)
        for _ in 0..<10 { await Task.yield() }
        check("opt-in sends available reports", Crashlytics.instance.sent == 1)
        setup(true); bootstrap()
        let enabledManager=FirebaseAnalyticsManager.testingInstance()
        enabledManager.setAnalyticsEnabled(false)
        Crashlytics.instance.checks[0](true)
        for _ in 0..<10 { await Task.yield() }
        check("opt-out invalidates pending send", Crashlytics.instance.sent == 0 && Crashlytics.instance.deleted == 1 && !Performance.instance.isDataCollectionEnabled)
        enabledManager.setAnalyticsEnabled(true)
        check("re-enable does not send a disabled-period queue", Crashlytics.instance.sent == 0 && Crashlytics.instance.checks.count == 1)
        setup(true); bootstrap()
        FirebaseMonitoring.resetLocalData()
        Crashlytics.instance.checks[0](true)
        for _ in 0..<10 { await Task.yield() }
        check("reset invalidates pending send", Crashlytics.instance.sent == 0 && Crashlytics.instance.deleted == 1)
        setup(true); bootstrap()
        Crashlytics.instance.checks[0](false)
        for _ in 0..<10 { await Task.yield() }
        check("empty crash queue is not sent", Crashlytics.instance.sent == 0)
        setup(true, previousSessionAllowed:false); bootstrap()
        check("disabled previous session is discarded after re-enable", Crashlytics.instance.deleted == 1 && Crashlytics.instance.checks.isEmpty)
        check("fresh enabled session may report on its next launch", UserDefaults.standard.bool(forKey:"firebase_diagnostics_previous_session_allowed"))
        FirebaseMonitoring.setEnabled(false); FirebaseMonitoring.setEnabled(true)
        check("off then on never restores current-session report permission", !UserDefaults.standard.bool(forKey:"firebase_diagnostics_previous_session_allowed"))
        FirebaseMonitoring.start(enabled:true)
        check("next launch drops entire mixed-consent session", Crashlytics.instance.deleted == 3 && Crashlytics.instance.checks.isEmpty)
        FirebaseMonitoring.resetLocalData()
        check("reset prevents later upload of current-session reports", !UserDefaults.standard.bool(forKey:"firebase_diagnostics_previous_session_allowed"))
        for environment in [["XCTestConfigurationFilePath":"fixture"],["XCODE_RUNNING_FOR_PREVIEWS":"1"]] {
            setup(true); ProcessInfo.processInfo.environment=environment; bootstrap()
            FirebaseMonitoring.start(enabled:true); FirebaseMonitoring.setEnabled(true); FirebaseMonitoring.resetLocalData()
            let isolatedManager=FirebaseAnalyticsManager.testingInstance()
            isolatedManager.setAnalyticsEnabled(true); isolatedManager.resetAnalyticsData(); isolatedManager.trackGameStart(gameType:"fixture")
            check("test/preview isolation", FirebaseApp.configurations == 0 && Crashlytics.instance.automaticChoices.isEmpty && !Performance.instance.isDataCollectionEnabled && Analytics.events.isEmpty && Analytics.collections.isEmpty && Analytics.resets == 0)
        }
        setup(true); ProcessInfo.processInfo.arguments=["--design-demo"]; bootstrap()
        check("design demo bypasses every SDK", FirebaseApp.configurations == 0 && Crashlytics.instance.checks.isEmpty && Analytics.collections.isEmpty)
        print("\(passed) Analytics/diagnostic privacy/session checks passed; zero network, SDK telemetry or audio.")
    }
}
