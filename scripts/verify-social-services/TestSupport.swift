import Foundation
import SwiftUI
import Combine

// Standalone audit: replacement transport and storage only. No app entrypoint,
// real auth SDK, networking, audio, persistent preferences or app containers.
func debugLog(_ value: @autoclosure () -> Any) {}
enum DesignDemo { static var isEnabled = false }
final class UserDefaults {
    static let standard = UserDefaults()
    var memory: [String: Data] = [:]
    func set(_ value: Data, forKey key: String) { memory[key] = value }
    func data(forKey key: String) -> Data? { memory[key] }
    func removePersistentDomain(forName name: String) { memory.removeAll() }
    func synchronize() {}
}
struct RecordedCall { let method: String; let path: String; let body: [String: Any]? }
final class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()
    @Published var user: User?
    @Published var isAuthenticated = false
    var calls: [RecordedCall] = []
    var handler: ((RecordedCall) async throws -> Data)?
    func reset() { calls = []; handler = nil; user = nil; isAuthenticated = false; UserDefaults.standard.memory = [:]; DesignDemo.isEnabled = false }
    func performRequest<T: Decodable>(method: String = "GET", path: String, body: [String: Any]? = nil, responseType: T.Type, headers: [String: String] = [:]) async throws -> T {
        guard user != nil, isAuthenticated else { throw APIError.notAuthenticated }
        let call = RecordedCall(method: method, path: path, body: body); calls.append(call)
        guard let handler else { throw AuditFailure(message: "Unconfigured mock request: \(path)") }
        return try JSONDecoder().decode(T.self, from: await handler(call))
    }
    func performVoidRequest(method: String = "POST", path: String, body: [String: Any], headers: [String: String] = [:]) async throws {
        guard user != nil, isAuthenticated else { throw APIError.notAuthenticated }
        let call = RecordedCall(method: method, path: path, body: body); calls.append(call)
        guard let handler else { throw AuditFailure(message: "Unconfigured mock mutation: \(path)") }
        _ = try await handler(call)
    }
    func signOut() async throws { user = nil; isAuthenticated = false }
}
struct AuditFailure: Error { let message: String }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws { if !condition() { throw AuditFailure(message: message) } }
func json(_ string: String) -> Data { Data(string.utf8) }
let auditA = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
let auditB = "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"
let auditC = "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"
func signInFixture(_ id: String = auditA, name: String = "FixtureA") {
    SupabaseClient.shared.user = User(id: id, email: "fixture@example.invalid", userMetadata: UserMetadata(username: name))
    SupabaseClient.shared.isAuthenticated = true
}
func relation(_ id: String, _ from: String, _ to: String, status: String = "accepted", fromName: String = "FixtureA", toName: String = "FixtureB") -> String {
    """
    {"id":"\(id)","user_id":"\(from)","friend_id":"\(to)","status":"\(status)","created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z","requester_username":"\(fromName)","recipient_username":"\(toName)"}
    """
}
let statsB = """
[{"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","username":"FixtureB","total_games":3,"best_score":90,"best_streak":2,"average_score":70,"total_correct":8,"total_questions":15}]
"""
let board = """
[{"rank":1,"username":"HiddenFixture","best_score":100,"total_games":3,"user_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"},{"rank":2,"username":"VisibleFixture","best_score":80,"total_games":2,"user_id":"cccccccc-cccc-cccc-cccc-cccccccccccc"}]
"""
@MainActor
func expectSocialError(_ expected: SocialError, _ operation: () async throws -> Void) async throws {
    do { try await operation(); throw AuditFailure(message: "Expected \(expected)") }
    catch let error as SocialError { try require(error == expected, "Wrong social error") }
}
