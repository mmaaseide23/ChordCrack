import Foundation
import AVFoundation
import Combine

/// A single playback owns its loading, players and completion. Resetting an attempt
/// cancels that work, so late downloads can never play in the following round.
@MainActor
final class AudioManager: NSObject, ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    @Published internal private(set) var playedChords: Set<String> = []
    @Published internal private(set) var currentSessionId = UUID()

    private var audioPlayers: [AVAudioPlayer] = []
    private var playbackTask: Task<Void, Never>?
    private var activeChordKey: String?
    private let loadAudio: (String) async throws -> Data

    override convenience init() {
        self.init(loadAudio: AudioManager.audioData)
    }

    /// Injectable loading makes failure/retry tests independent of the network.
    init(loadAudio: @escaping (String) async throws -> Data) {
        self.loadAudio = loadAudio
        super.init()
    }

    func playChord(_ chord: ChordType,
                   hintType: GameManager.HintType = .chordNoFingers,
                   audioOption: GameManager.AudioOption = .chord) {
        let key = "\(chord.rawValue)-\(currentSessionId.uuidString)"
        guard !isLoading, !isPlaying, !playedChords.contains(key) else { return }
        var files = chord.getStringFiles()
        var spacing: TimeInterval = 0
        var individual = false
        switch hintType {
        case .chordNoFingers, .singleFingerReveal: break
        case .chordSlow: spacing = 0.15
        case .individualStrings: individual = true
        case .audioOptions:
            switch audioOption {
            case .chord: break
            case .individual: individual = true
            case .bass: files = files.filter { ["E2_", "A3_", "D3_"].contains(where: $0.hasPrefix) }
            case .treble: files = files.filter { ["G3_", "B4_", "E4_"].contains(where: $0.hasPrefix) }
            }
        }
        beginPlayback(groups: [files], chordKey: key, stringSpacing: spacing,
                      individual: individual, chordSpacing: 0) {
            FirebaseAnalyticsManager.shared.trackAudioPlayback(chordType: chord.rawValue, audioOption: audioOption.analyticsValue)
        }
    }

    func playChordSequence(_ chords: [ChordType], delayBetween: TimeInterval = 1.2,
                           onCompletion: (() -> Void)? = nil) {
        guard !chords.isEmpty else { onCompletion?(); return }
        resetForNewAttempt()
        beginPlayback(groups: chords.map { $0.getStringFiles() }, chordKey: nil,
                      stringSpacing: 0, individual: false, chordSpacing: max(0.1, delayBetween),
                      onStart: {}, onCompletion: onCompletion)
    }

    func resetForNewAttempt() {
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayers.forEach { $0.stop() }
        audioPlayers.removeAll()
        currentSessionId = UUID()
        playedChords.removeAll()
        activeChordKey = nil
        isLoading = false
        isPlaying = false
        errorMessage = nil
    }

    func resetForNewRound() { resetForNewAttempt() }

    private func beginPlayback(groups: [[String]], chordKey: String?, stringSpacing: TimeInterval,
                               individual: Bool, chordSpacing: TimeInterval,
                               onStart: @escaping () -> Void, onCompletion: (() -> Void)? = nil) {
        let session = currentSessionId
        isLoading = true
        errorMessage = nil
        activeChordKey = chordKey
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                guard groups.allSatisfy({ !$0.isEmpty }) else { throw PlaybackError.unavailable }
                var scheduled: [(player: AVAudioPlayer, offset: TimeInterval)] = []
                // Load the whole phrase first. Missing a string is a failed listen,
                // not a partial chord for the player to identify.
                for (groupIndex, files) in groups.enumerated() {
                    var offset = Double(groupIndex) * chordSpacing
                    for file in files {
                        let data = try await loadAudio(file)
                        try Task.checkCancellation()
                        guard session == currentSessionId else { return }
                        let player = try AVAudioPlayer(data: data)
                        player.delegate = self
                        player.volume = individual ? 1 : 0.8
                        guard player.prepareToPlay() else { throw PlaybackError.unavailable }
                        scheduled.append((player, offset))
                        offset += individual ? player.duration + 0.12 : stringSpacing
                    }
                }
                try activateSession()
                try Task.checkCancellation()
                guard session == currentSessionId, let first = scheduled.first else { return }
                audioPlayers = scheduled.map(\.player)
                let start = first.player.deviceCurrentTime + 0.05
                for item in scheduled {
                    guard item.player.play(atTime: start + item.offset) else { throw PlaybackError.unavailable }
                }
                // Consume a listen only after every sound has loaded and playback starts.
                if let chordKey { playedChords.insert(chordKey) }
                isLoading = false
                isPlaying = true
                onStart()
                NotificationCenter.default.post(name: NSNotification.Name("AudioStarted"), object: nil)
                let duration = scheduled.map { $0.offset + $0.player.duration }.max() ?? 0
                try await Task.sleep(for: .seconds(duration + 0.1))
                guard session == currentSessionId else { return }
                isPlaying = false
                audioPlayers.removeAll()
                playbackTask = nil
                onCompletion?()
            } catch {
                guard session == currentSessionId, !Task.isCancelled else { return }
                failPlayback(error)
            }
        }
    }

    private func activateSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .duckOthers])
        try session.setActive(true)
        #endif
    }

    private func failPlayback(_ error: Error) {
        audioPlayers.forEach { $0.stop() }
        audioPlayers.removeAll()
        if let activeChordKey { playedChords.remove(activeChordKey) }
        isLoading = false
        isPlaying = false
        errorMessage = (error as? URLError)?.code == .notConnectedToInternet
            ? "You're offline. Connect to load this chord, then try again."
            : "Couldn't play the full chord. Your listen is still available — try again."
    }

    private static func audioData(named file: String) async throws -> Data {
        if DesignDemo.isEnabled {
            guard let data = DesignDemo.stringTone(named: file) else { throw PlaybackError.unavailable }
            return data
        }
        if let cached = AudioCacheManager.shared.cachedData(for: file) { return cached }
        guard let url = URL(string: "https://raw.githubusercontent.com/mmaaseide23/Chordle_Assets/main/\(file)") else {
            throw PlaybackError.unavailable
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count > 100 else {
            throw PlaybackError.unavailable
        }
        // Don't persist corrupt or non-audio responses.
        _ = try AVAudioPlayer(data: data)
        try Task.checkCancellation()
        AudioCacheManager.shared.cacheData(data, for: file)
        return data
    }

    private enum PlaybackError: Error { case unavailable }
}

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard self.audioPlayers.contains(where: { $0 === player }) else { return }
            self.playbackTask?.cancel()
            self.playbackTask = nil
            self.failPlayback(error ?? PlaybackError.unavailable)
        }
    }
}
