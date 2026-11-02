import Foundation
import SwiftUI

// Shadow dependencies only; the production manager's control flow is unchanged.
final class UserDefaults {
    static let standard = UserDefaults()
    var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}
struct Date {
    static var clock: TimeInterval = 0
    let time = Self.clock
    func timeIntervalSince(_ other: Date) -> TimeInterval { time - other.time }
}
enum DesignDemo { static var isEnabled = false }
enum FirebaseApp {
    static var configurations = 0
    static func configure() { configurations += 1 }
}
enum Analytics {
    static var collections: [Bool] = []
    static var events: [(String, [String: Any])] = []
    static var properties: [(String, String?)] = []
    static var resets = 0
    static func setAnalyticsCollectionEnabled(_ enabled: Bool) { collections.append(enabled) }
    static func logEvent(_ name: String, parameters: [String: Any]?) { events.append((name, parameters ?? [:])) }
    static func setUserProperty(_ value: String?, forName name: String) { properties.append((name, value)) }
    static func resetAnalyticsData() { resets += 1 }
    static func clear() { collections=[]; events=[]; properties=[]; resets=0 }
}
let AnalyticsEventScreenView = "screen_view"
let AnalyticsParameterScreenName = "screen_name"
final class GameManager {
    enum State { case gameOver, playing }
    var gameState: State = .playing
    var isGameCompleted=false, isGameActive=false
    var totalQuestions=0, totalCorrect=0, score=0, bestStreak=0, currentRound=1
}

final class ProcessInfo {
    static let processInfo = ProcessInfo()
    var arguments: [String] = []
    var environment: [String: String] = [:]
}
final class Performance {
    static let instance = Performance()
    static func sharedInstance() -> Performance { instance }
    var isInstrumentationEnabled = false
    var isDataCollectionEnabled = false
}
final class Crashlytics {
    static let instance = Crashlytics()
    static func crashlytics() -> Crashlytics { instance }
    var automaticChoices: [Bool] = []
    var checks: [(Bool)->Void] = []
    var sent=0, deleted=0
    func setCrashlyticsCollectionEnabled(_ enabled: Bool) { automaticChoices.append(enabled) }
    func deleteUnsentReports() { deleted += 1 }
    func sendUnsentReports() { sent += 1 }
    func checkForUnsentReports(completion: @escaping (Bool)->Void) { checks.append(completion) }
    func clear() { automaticChoices=[]; checks=[]; sent=0; deleted=0 }
}
extension FirebaseMonitoring {
    static func resetTestState() { isConfigured=false; isEnabled=false; revision=0 }
}
