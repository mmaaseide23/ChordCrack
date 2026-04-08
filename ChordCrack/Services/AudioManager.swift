import Foundation
import AVFoundation
import Combine
import FirebaseAnalytics

/// Professional audio management system for chord playback with thread safety
/// Handles multiple audio playback modes with robust error handling
@MainActor
final class AudioManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var isPlaying = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private var audioPlayers: [AVAudioPlayer] = []
    private var audioSession: AVAudioSession
    private var downloadTasks: [URLSessionDataTask] = []
    private let maxConcurrentDownloads = 6
    private var suppressErrors = false // Flag to suppress non-critical errors
    private let analytics = FirebaseAnalyticsManager.shared
    
    // Track play state per chord instead of globally
    internal var playedChords: Set<String> = []
    internal var currentSessionId: UUID = UUID()
    
    // MARK: - Initialization
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func playChord(_ chord: ChordType, hintType: GameManager.HintType = .chordNoFingers, audioOption: GameManager.AudioOption = .chord) {
        let chordKey = "\(chord.rawValue)-\(currentSessionId.uuidString)"
        
        guard !isLoading && !playedChords.contains(chordKey) else {
            debugLog("[AudioManager] Playback blocked for chord: \(chord.rawValue)")
            return
        }
        
        // ADD ANALYTICS TRACKING HERE (after validation)
        analytics.trackAudioPlayback(chordType: chord.rawValue, audioOption: audioOption.analyticsValue)
        
        // Enable error suppression for audio playback
        suppressErrors = true
        
        // ... rest of your existing playChord method stays the same
        logPlaybackStart(chord: chord, hintType: hintType, audioOption: audioOption)
        
        prepareForPlayback()
        playedChords.insert(chordKey)
        
        let stringFiles = chord.getStringFiles()
        
        guard validateChordAudioFiles(stringFiles) else {
            debugLog("[AudioManager] Chord validation failed for: \(chord.rawValue)")
            isLoading = false
            return
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("AudioStarted"), object: nil)
        
        executePlaybackStrategy(stringFiles: stringFiles, hintType: hintType, audioOption: audioOption)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.suppressErrors = false
        }
    }
    
    func resetForNewAttempt() {
        // Create new session ID to reset played state
        currentSessionId = UUID()
        playedChords.removeAll()
        errorMessage = nil
        suppressErrors = false
    }
    
    func resetForNewRound() {
        // Complete reset for new round
        currentSessionId = UUID()
        playedChords.removeAll()
        errorMessage = nil
        suppressErrors = false
    }
    
    // MARK: - Private Setup Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers])
            try audioSession.setActive(true)
            debugLog("[AudioManager] Audio session configured successfully")
        } catch {
            // Silently handle audio session setup errors
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
            // Silently handle deactivation errors
        }
    }
    
    // MARK: - Validation Methods
    
    private func prepareForPlayback() {
        isLoading = true
        errorMessage = nil
        
        // Cancel existing operations
        downloadTasks.forEach { $0.cancel() }
        downloadTasks.removeAll()
        audioPlayers.removeAll()
    }
    
    // MARK: - Logging Methods
    
    private func logPlaybackStart(chord: ChordType, hintType: GameManager.HintType, audioOption: GameManager.AudioOption) {
        debugLog("[AudioManager] 🎵 Playing chord: \(chord.rawValue)")
        debugLog("[AudioManager] 🎭 Hint type: \(hintType)")
        debugLog("[AudioManager] 🎛️ Audio option: \(audioOption)")
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
            debugLog("[AudioManager] No string files to play")
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
            debugLog("[AudioManager] No audio data to play")
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
                // Silently handle player creation errors
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
        debugLog("[AudioManager] ✅ Playing \(audioPlayers.count) simultaneous audio files")
    }
    
    // MARK: - Sequential Playback Methods
    
    private func playStringSequence(stringFiles: [String], delay: Double) {
        debugLog("[AudioManager] 🔄 Starting sequence: \(stringFiles.count) files, delay: \(delay)s")
        isLoading = false
        
        guard !stringFiles.isEmpty else {
            debugLog("[AudioManager] No string files to play")
            isPlaying = false
            return
        }
        
        audioPlayers.removeAll()
        isPlaying = true
        
        playSequentialAudio(files: stringFiles, delay: delay, currentIndex: 0)
    }
    
    private func playSequentialAudio(files: [String], delay: Double, currentIndex: Int) {
        guard currentIndex < files.count else {
            debugLog("[AudioManager] ✅ Sequence complete")
            Task { @MainActor in
                self.isPlaying = false
            }
            return
        }
        
        let fileName = files[currentIndex]
        debugLog("[AudioManager] 🎵 Playing \(currentIndex + 1)/\(files.count): \(fileName)")
        
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
                scheduleNextInSequence(files: files, delay: delay, currentIndex: currentIndex)
                return
            }
            
            guard player.play() else {
                scheduleNextInSequence(files: files, delay: delay, currentIndex: currentIndex)
                return
            }
            
            debugLog("[AudioManager] ✅ Successfully playing audio \(currentIndex + 1)/\(files.count)")
            
            // Use the full audio duration plus a small gap to prevent overlapping
            let audioDelay = player.duration // Small gap between strings
            DispatchQueue.main.asyncAfter(deadline: .now() + audioDelay) { [weak self] in
                self?.playSequentialAudio(files: files, delay: delay, currentIndex: currentIndex + 1)
            }
            
        } catch {
            // Silently handle audio creation errors
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
    
    private func validateChordAudioFiles(_ stringFiles: [String]) -> Bool {
        for fileName in stringFiles {
            // Check basic format
            guard fileName.hasSuffix(".m4a") else {
                debugLog("[AudioManager] Invalid file extension: \(fileName)")
                // Don't show error to user
                return false
            }
            
            // Parse and validate components
            let nameWithoutExtension = fileName.dropLast(4)
            let components = nameWithoutExtension.split(separator: "_")
            
            guard components.count == 2 else {
                debugLog("[AudioManager] Invalid file name structure: \(fileName)")
                // Don't show error to user
                return false
            }
            
            let stringName = String(components[0])
            let validStrings = ["E2", "A3", "D3", "G3", "B4", "E4"]
            
            guard validStrings.contains(stringName) else {
                debugLog("[AudioManager] Unknown string: \(stringName) in \(fileName)")
                // Don't show error to user
                return false
            }
            
            // Validate fret number
            if let fretPart = components[1].split(separator: "t").last,
               let fretNumber = Int(fretPart) {
                if stringName == "E4" {
                    guard fretNumber >= 0 && fretNumber <= 12 else {
                        debugLog("[AudioManager] E4 fret out of range: \(fretNumber)")
                        // Don't show error to user
                        return false
                    }
                } else {
                    guard fretNumber >= 0 && fretNumber <= 4 else {
                        debugLog("[AudioManager] \(stringName) fret out of range: \(fretNumber)")
                        // Don't show error to user
                        return false
                    }
                }
            } else {
                debugLog("[AudioManager] Cannot parse fret number from: \(fileName)")
                // Don't show error to user
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Audio Download Methods (with disk cache)

    private nonisolated var audioCache: AudioCacheManager { AudioCacheManager.shared }

    private func downloadAudioFile(fileName: String, completion: @escaping (Data?) -> Void) {
        // Validate file name format
        guard fileName.hasSuffix(".m4a") else {
            debugLog("[AudioManager] Invalid file name format: \(fileName)")
            completion(nil)
            return
        }

        let components = fileName.dropLast(4).split(separator: "_")
        if components.count != 2 {
            debugLog("[AudioManager] Invalid file name structure: \(fileName)")
            completion(nil)
            return
        }

        let validStrings = ["E2", "A3", "D3", "G3", "B4", "E4"]
        let stringName = String(components[0])

        guard validStrings.contains(stringName) else {
            debugLog("[AudioManager] Invalid string name in file: \(fileName)")
            completion(nil)
            return
        }

        if let fretString = components[1].split(separator: "t").last,
           let fretNumber = Int(fretString) {
            if stringName == "E4" && (fretNumber < 0 || fretNumber > 12) {
                debugLog("[AudioManager] Invalid E4 fret number: \(fretNumber)")
                completion(nil)
                return
            } else if stringName != "E4" && (fretNumber < 0 || fretNumber > 4) {
                debugLog("[AudioManager] Invalid \(stringName) fret number: \(fretNumber)")
                completion(nil)
                return
            }
        }

        // Check disk cache first
        if let cachedData = audioCache.cachedData(for: fileName) {
            debugLog("[AudioManager] \u{1F4E6} Cache hit: \(fileName)")
            completion(cachedData)
            return
        }

        // Download from network
        let urlString = "https://raw.githubusercontent.com/mmaaseide23/Chordle_Assets/main/\(fileName)"

        guard let url = URL(string: urlString) else {
            debugLog("[AudioManager] Invalid URL for: \(fileName)")
            completion(nil)
            return
        }

        debugLog("[AudioManager] \u{1F4E5} Downloading: \(fileName)")

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                debugLog("[AudioManager] Download error for \(fileName): \(error.localizedDescription)")

                if !(self?.suppressErrors ?? false) {
                    if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                        Task { @MainActor in
                            self?.errorMessage = "No internet — play online once to cache audio"
                        }
                    }
                }

                completion(nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    debugLog("[AudioManager] HTTP error \(httpResponse.statusCode) for \(fileName)")
                    completion(nil)
                    return
                }
            }

            guard let data = data, !data.isEmpty else {
                debugLog("[AudioManager] No data received for \(fileName)")
                completion(nil)
                return
            }

            if data.count < 100 {
                debugLog("[AudioManager] Suspiciously small audio file: \(data.count) bytes")
                completion(nil)
                return
            }

            // Cache to disk for offline use
            self?.audioCache.cacheData(data, for: fileName)
            debugLog("[AudioManager] \u{2705} Downloaded & cached \(fileName) (\(data.count) bytes)")
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
            // Only show decode errors if not suppressed
            if !self.suppressErrors {
                self.errorMessage = "Audio playback error"
                debugLog("[AudioManager] Decode error: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
}
