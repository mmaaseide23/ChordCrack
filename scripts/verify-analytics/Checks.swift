extension FirebaseAnalyticsManager {
    static func testingInstance() -> FirebaseAnalyticsManager { FirebaseAnalyticsManager() }
}
@main struct Checks {
    @MainActor static func main() {
        var passed=0
        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            guard condition() else { fatalError("FAIL: \(name)") }
            passed += 1
        }
        func setup(_ preference: Bool?) {
            UserDefaults.standard.values = [:]
            UserDefaults.standard.set(preference, forKey: "firebase_analytics_enabled")
            Analytics.clear(); FirebaseApp.configurations=0; DesignDemo.isEnabled=false; Date.clock=0
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
        check("existing new-user default retained", Analytics.collections == [true] && UserDefaults.standard.values.isEmpty)
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
        print("\(passed) Analytics privacy/session checks passed; zero network, SDK telemetry or audio.")
    }
}
