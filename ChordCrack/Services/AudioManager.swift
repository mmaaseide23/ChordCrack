import Foundation
import AVFoundation
import Combine

/// Professional audio management system for chord playback with thread safety
/// Handles multiple audio playback modes with robust error handling
@MainActor
final class AudioManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var isPlaying = false
    @Published var errorMessage: String?
    @Published var hasPlayedThisAttempt = false
    
    // MARK: - Private Properties
    
    private var audioPlayers: [AVAudioPlayer] = []
    private var audioSession: AVAudioSession
    private var downloadTasks: [URLSessionDataTask] = []
    private let maxConcurrentDownloads = 6
    
    // MARK: - Initialization
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
    }
    
    
    // MARK: - Public Methods
    
    func playChord(_ chord: ChordType, hintType: GameManager.HintType = .chordNoFingers, audioOption: GameManager.AudioOption = .chord) {
        guard validatePlaybackConditions() else { return }
        
        logPlaybackStart(chord: chord, hintType: hintType, audioOption: audioOption)
        
        prepareForPlayback()
        let stringFiles = chord.getStringFiles()
        
        // Trigger visual feedback
        NotificationCenter.default.post(name: NSNotification.Name("AudioStarted"), object: nil)
        
        executePlaybackStrategy(stringFiles: stringFiles, hintType: hintType, audioOption: audioOption)
    }
    
    func resetForNewAttempt() {
        hasPlayedThisAttempt = false
        errorMessage = nil
    }
    
    // MARK: - Private Setup Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers])
            try audioSession.setActive(true)
            print("[AudioManager] Audio session configured successfully")
        } catch {
            print("[AudioManager] Failed to setup audio session: \(error)")
            errorMessage = "Audio setup failed: \(error.localizedDescription)"
        }
    }
    
    private func cleanupAudioResources() {
        downloadTasks.forEach { $0.cancel() }
        downloadTasks.removeAll()
        audioPlayers.forEach { $0.stop() }
        audioPlayers.removeAll()
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("[AudioManager] Error deactivating audio session: \(error)")
        }
    }
    
    // MARK: - Validation Methods
    
    private func validatePlaybackConditions() -> Bool {
        guard !isLoading && !hasPlayedThisAttempt else {
            print("[AudioManager] Playback blocked - isLoading: \(isLoading), hasPlayedThisAttempt: \(hasPlayedThisAttempt)")
            return false
        }
        return true
    }
    
    private func prepareForPlayback() {
        isLoading = true
        errorMessage = nil
        hasPlayedThisAttempt = true
        
        // Cancel existing operations
        downloadTasks.forEach { $0.cancel() }
        downloadTasks.removeAll()
        audioPlayers.removeAll()
    }
    
    // MARK: - Logging Methods
    
    private func logPlaybackStart(chord: ChordType, hintType: GameManager.HintType, audioOption: GameManager.AudioOption) {
        print("[AudioManager] 🎵 Playing chord: \(chord.rawValue)")
        print("[AudioManager] 🎭 Hint type: \(hintType)")
        print("[AudioManager] 🎛️ Audio option: \(audioOption)")
    }
    
    // MARK: - Playback Strategy Methods
    
    private func executePlaybackStrategy(stringFiles: [String], hintType: GameManager.HintType, audioOption: GameManager.AudioOption) {
        switch hintType {
        case .chordNoFingers:
            playChordSimultaneous(stringFiles: stringFiles)
        case .chordSlow:
            playStringSequence(stringFiles: stringFiles, delay: 0.15)
        case .individualStrings:
            playStringSequence(stringFiles: stringFiles, delay: 0.3)
        case .audioOptions:
            playSelectedAudioOption(stringFiles: stringFiles, option: audioOption)
        case .singleFingerReveal:
            playChordSimultaneous(stringFiles: stringFiles)
        }
    }
    
    private func playSelectedAudioOption(stringFiles: [String], option: GameManager.AudioOption) {
        switch option {
        case .chord:
            playChordSimultaneous(stringFiles: stringFiles)
        case .individual:
            playStringSequence(stringFiles: stringFiles, delay: 0.4)
        case .bass:
            let bassStrings = getBassStrings(from: stringFiles)
            playChordSimultaneous(stringFiles: bassStrings)
        case .treble:
            let trebleStrings = getTrebleStrings(from: stringFiles)
            playChordSimultaneous(stringFiles: trebleStrings)
        }
    }
    
    // MARK: - String Selection Helpers
    
    private func getBassStrings(from stringFiles: [String]) -> [String] {
        // Bass strings are typically the lower pitched strings (E2, A3, D3)
        // Filter for files containing E2, A3, D3
        return stringFiles.filter { fileName in
            fileName.contains("E2_") || fileName.contains("A3_") || fileName.contains("D3_")
        }
    }
    
    private func getTrebleStrings(from stringFiles: [String]) -> [String] {
        // Treble strings are typically the higher pitched strings (G3, B4, E4)
        // Filter for files containing G3, B4, E4
        return stringFiles.filter { fileName in
            fileName.contains("G3_") || fileName.contains("B4_") || fileName.contains("E4_")
        }
    }
    
    // MARK: - Simultaneous Playback Methods
    
    private func playChordSimultaneous(stringFiles: [String]) {
        guard !stringFiles.isEmpty else {
            print("[AudioManager] ⚠️ No string files to play")
            isLoading = false
            return
        }
        
        let group = DispatchGroup()
        var audioDataArray: [(Data, Int)] = []
        let dataLock = NSLock()
        
        for (index, fileName) in stringFiles.enumerated() {
            group.enter()
            downloadAudioFile(fileName: fileName) { data in
                if let data = data {
                    dataLock.lock()
                    audioDataArray.append((data, index))
                    dataLock.unlock()
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.playSimultaneousAudio(audioDataArray.sorted { $0.1 < $1.1 }.map { $0.0 })
        }
    }
    
    private func playSimultaneousAudio(_ audioDataArray: [Data]) {
        audioPlayers.removeAll()
        
        guard !audioDataArray.isEmpty else {
            print("[AudioManager] ⚠️ No audio data to play")
            return
        }
        
        for data in audioDataArray {
            do {
                let player = try AVAudioPlayer(data: data)
                player.delegate = self
                player.volume = 0.8 // Balanced volume for multiple sounds
                player.prepareToPlay()
                audioPlayers.append(player)
            } catch {
                print("[AudioManager] Failed to create player: \(error)")
            }
        }
        
        // Synchronize playback start
        guard !audioPlayers.isEmpty else { return }
        
        let startTime = audioPlayers.first?.deviceCurrentTime ?? 0
        let playTime = startTime + 0.01
        
        for player in audioPlayers {
            player.play(atTime: playTime)
        }
        
        isPlaying = true
        print("[AudioManager] ✅ Playing \(audioPlayers.count) simultaneous audio files")
    }
    
    // MARK: - Sequential Playback Methods
    
    private func playStringSequence(stringFiles: [String], delay: Double) {
        print("[AudioManager] 🔄 Starting sequence: \(stringFiles.count) files, delay: \(delay)s")
        isLoading = false
        
        guard !stringFiles.isEmpty else {
            print("[AudioManager] ⚠️ No string files to play")
            isPlaying = false
            return
        }
        
        audioPlayers.removeAll()
        isPlaying = true
        
        playSequentialAudio(files: stringFiles, delay: delay, currentIndex: 0)
    }
    
    private func playSequentialAudio(files: [String], delay: Double, currentIndex: Int) {
        guard currentIndex < files.count else {
            print("[AudioManager] ✅ Sequence complete")
            Task { @MainActor in
                self.isPlaying = false
            }
            return
        }
        
        let fileName = files[currentIndex]
        print("[AudioManager] 🎵 Playing \(currentIndex + 1)/\(files.count): \(fileName)")
        
        downloadAudioFile(fileName: fileName) { [weak self] data in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let data = data {
                    self.playNextSequentialAudio(data: data, files: files, delay: delay, currentIndex: currentIndex)
                } else {
                    // If download failed, continue with next file
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.playSequentialAudio(files: files, delay: delay, currentIndex: currentIndex + 1)
                    }
                }
            }
        }
    }
    
    private func playNextSequentialAudio(data: Data, files: [String], delay: Double, currentIndex: Int) {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.volume = 1.0
            
            audioPlayers.append(player) // Keep reference to prevent deallocation
            
            guard player.prepareToPlay() else {
                print("[AudioManager] ⚠️ Failed to prepare audio player")
                scheduleNextInSequence(files: files, delay: delay, currentIndex: currentIndex)
                return
            }
            
            guard player.play() else {
                print("[AudioManager] ⚠️ Failed to start audio playback")
                scheduleNextInSequence(files: files, delay: delay, currentIndex: currentIndex)
                return
            }
            
            print("[AudioManager] ✅ Successfully playing audio \(currentIndex + 1)/\(files.count)")
            
            // Use the full audio duration plus a small gap to prevent overlapping
            let audioDelay = player.duration // Small gap between strings
            DispatchQueue.main.asyncAfter(deadline: .now() + audioDelay) { [weak self] in
                self?.playSequentialAudio(files: files, delay: delay, currentIndex: currentIndex + 1)
            }
            
        } catch {
            print("[AudioManager] ⚠️ Audio creation error: \(error)")
            scheduleNextInSequence(files: files, delay: delay, currentIndex: currentIndex)
        }
    }
    
    private func calculateSequenceDelay(delay: Double, audioDuration: TimeInterval) -> Double {
        // For individual strings, wait for most of the audio plus the specified delay
        return max(delay * 0.6, audioDuration * 0.8)
    }
    
    private func scheduleNextInSequence(files: [String], delay: Double, currentIndex: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.playSequentialAudio(files: files, delay: delay, currentIndex: currentIndex + 1)
        }
    }
    
    // MARK: - Audio Download Methods
    
    private func downloadAudioFile(fileName: String, completion: @escaping (Data?) -> Void) {
        let urlString = "https://raw.githubusercontent.com/mmaaseide23/Chordle_Assets/main/\(fileName)"
        
        guard let url = URL(string: urlString) else {
            print("[AudioManager] ⚠️ Invalid URL for: \(fileName)")
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("[AudioManager] ⚠️ Download error for \(fileName): \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("[AudioManager] ⚠️ No data received for \(fileName)")
                completion(nil)
                return
            }
            
            print("[AudioManager] ✅ Downloaded \(fileName) (\(data.count) bytes)")
            completion(data)
        }
        
        downloadTasks.append(task)
        task.resume()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            // Only set to false if no other players are active
            let hasActivePlayers = self.audioPlayers.contains { $0.isPlaying }
            if !hasActivePlayers {
                self.isPlaying = false
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isPlaying = false
            self.errorMessage = "Audio decode error: \(error?.localizedDescription ?? "Unknown error")"
            print("[AudioManager] ⚠️ Decode error: \(self.errorMessage ?? "Unknown")")
        }
    }
}
