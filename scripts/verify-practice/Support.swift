import Foundation
import SwiftUI

func debugLog(_ message: String) {}

// A deliberately silent substitute. No AVFoundation playback API is invoked by this runner.
protocol AVAudioPlayerDelegate: AnyObject {}
final class AVAudioPlayer: NSObject {
    static var startSucceeds = true
    static var prepared = 0
    static var started = 0
    static var stopped = 0
    weak var delegate: AVAudioPlayerDelegate?
    var volume: Float = 1
    let duration: TimeInterval = 0.01
    let deviceCurrentTime: TimeInterval = 0
    init(data: Data) throws {
        guard data.starts(with: Data("RIFF".utf8)) else { throw URLError(.cannotDecodeContentData) }
    }
    func prepareToPlay() -> Bool { Self.prepared += 1; return true }
    func play(atTime: TimeInterval) -> Bool { Self.started += 1; return Self.startSucceeds }
    func stop() { Self.stopped += 1 }
    static func reset() { startSucceeds = true; prepared = 0; started = 0; stopped = 0 }
}

enum GameManager {
    enum HintType { case chordNoFingers, singleFingerReveal, chordSlow, individualStrings, audioOptions }
    enum AudioOption: String { case chord, individual, bass, treble; var analyticsValue: String { rawValue } }
}
final class FirebaseAnalyticsManager {
    static let shared = FirebaseAnalyticsManager()
    func trackAudioPlayback(chordType: String, audioOption: String) {}
}
final class AudioCacheManager {
    static let shared = AudioCacheManager()
    func cachedData(for file: String) -> Data? { fatalError("Unexpected cache access") }
    func cacheData(_ data: Data, for file: String) { fatalError("Unexpected cache access") }
}

enum CheckFailure: Error { case failed(String) }
func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckFailure.failed(message) }
}
@MainActor func eventually(_ predicate: () -> Bool) async throws {
    for _ in 0..<200 {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw CheckFailure.failed("Timed out waiting for state")
}
