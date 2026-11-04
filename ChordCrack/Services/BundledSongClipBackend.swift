#if os(iOS)
import Foundation
import AVFoundation
import CryptoKit

/// Future cleared bundle assets only. This adapter cannot stream provider content or play fixtures.
@MainActor final class BundledSongClipBackend: SongClipPlaybackBackend {
    private let file: AVAudioFile
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var ownsAudioSession = false
    var sampleRate: Double { file.processingFormat.sampleRate }
    var frameLength: Int64 { file.length }

    init(clip: SongClip, bundle: Bundle = .main) throws {
        guard clip.kind == .recording, clip.isWellFormed else { throw SongPlaybackError.uncleared }
        guard let url = bundle.url(forResource: clip.bundledFile, withExtension: nil) else { throw SongPlaybackError.missingAsset }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == clip.sha256 else { throw SongPlaybackError.wrongAsset }
        file = try AVAudioFile(forReading: url)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
    }
    func play(_ range: SongFrameRange, completion: @escaping () -> Void) throws {
        guard range.start >= 0, range.count > 0,
              range.start <= file.length - Int64(range.count) else { throw SongPlaybackError.invalidSegment }
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .duckOthers])
        try audio.setActive(true)
        ownsAudioSession = true
        try engine.start()
        node.scheduleSegment(file, startingFrame: range.start, frameCount: range.count, at: nil,
                             completionCallbackType: .dataPlayedBack) { _ in
            Task { @MainActor in completion() }
        }
        node.play()
    }
    func stop() {
        node.stop(); engine.stop()
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }
}
#endif
