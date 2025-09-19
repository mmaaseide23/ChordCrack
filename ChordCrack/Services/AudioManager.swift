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
    
    // MARK: - Private Properties
    
    private var audioPlayers: [AVAudioPlayer] = []
    private var audioSession: AVAudioSession
    private var downloadTasks: [URLSessionDataTask] = []
    private let maxConcurrentDownloads = 6
    
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
            print("[AudioManager] Playback blocked for chord: \(chord.rawValue)")
            return
        }
        
        logPlaybackStart(chord: chord, hintType: hintType, audioOption: audioOption)
        
        prepareForPlayback()
        playedChords.insert(chordKey)
        
        let stringFiles = chord.getStringFiles()
        
        // Validate files before attempting to play
        guard validateChordAudioFiles(stringFiles) else {
            print("[AudioManager] ⚠️ Chord validation failed for: \(chord.rawValue)")
            isLoading = false
            // Error message already set by validateChordAudioFiles
            return
        }
        
        // Trigger visual feedback
        NotificationCenter.default.post(name: NSNotification.Name("AudioStarted"), object: nil)
        
        executePlaybackStrategy(stringFiles: stringFiles, hintType: hintType, audioOption: audioOption)
    }
    
    func resetForNewAttempt() {
        // Create new session ID to reset played state
        currentSessionId = UUID()
        playedChords.removeAll()
        errorMessage = nil
    }
    
    func resetForNewRound() {
        // Complete reset for new round
        currentSessionId = UUID()
        playedChords.removeAll()
        errorMessage = nil
    }
    
    // MARK: - Private Setup Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers])
            try audioSession.setActive(true)
            print("[AudioManager] Audio session configured successfully")
        } catch {
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
    
    private func validateChordAudioFiles(_ stringFiles: [String]) -> Bool {
        for fileName in stringFiles {
            // Check basic format
            guard fileName.hasSuffix(".m4a") else {
                print("[AudioManager] ⚠️ Invalid file extension: \(fileName)")
                errorMessage = "Invalid audio file format"
                return false
            }
            
            // Parse and validate components
            let nameWithoutExtension = fileName.dropLast(4)
            let components = nameWithoutExtension.split(separator: "_")
            
            guard components.count == 2 else {
                print("[AudioManager] ⚠️ Invalid file name structure: \(fileName)")
                errorMessage = "Audio configuration error"
                return false
            }
            
            let stringName = String(components[0])
            let validStrings = ["E2", "A3", "D3", "G3", "B4", "E4"]
            
            guard validStrings.contains(stringName) else {
                print("[AudioManager] ⚠️ Unknown string: \(stringName) in \(fileName)")
                errorMessage = "Invalid chord configuration"
                return false
            }
            
            // Validate fret number
            if let fretPart = components[1].split(separator: "t").last,
               let fretNumber = Int(fretPart) {
                if stringName == "E4" {
                    guard fretNumber >= 0 && fretNumber <= 12 else {
                        print("[AudioManager] ⚠️ E4 fret out of range: \(fretNumber)")
                        errorMessage = "Chord uses unavailable fret positions"
                        return false
                    }
                } else {
                    guard fretNumber >= 0 && fretNumber <= 4 else {
                        print("[AudioManager] ⚠️ \(stringName) fret out of range: \(fretNumber)")
                        errorMessage = "Chord uses unavailable fret positions"
                        return false
                    }
                }
            } else {
                print("[AudioManager] ⚠️ Cannot parse fret number from: \(fileName)")
                errorMessage = "Invalid fret configuration"
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Audio Download Methods
    
    private func downloadAudioFile(fileName: String, completion: @escaping (Data?) -> Void) {
        // Add validation for file name format
        guard fileName.hasSuffix(".m4a") else {
            print("[AudioManager] ⚠️ Invalid file name format: \(fileName)")
            Task { @MainActor in
                self.errorMessage = "Invalid audio file format"
            }
            completion(nil)
            return
        }
        
        // Validate string and fret components
        let components = fileName.dropLast(4).split(separator: "_")
        if components.count != 2 {
            print("[AudioManager] ⚠️ Invalid file name structure: \(fileName)")
            completion(nil)
            return
        }
        
        let validStrings = ["E2", "A3", "D3", "G3", "B4", "E4"]
        let stringName = String(components[0])
        
        guard validStrings.contains(stringName) else {
            print("[AudioManager] ⚠️ Invalid string name in file: \(fileName)")
            completion(nil)
            return
        }
        
        // Check if fret number is valid
        if let fretString = components[1].split(separator: "t").last,
           let fretNumber = Int(fretString) {
            // Validate fret ranges
            if stringName == "E4" && (fretNumber < 0 || fretNumber > 12) {
                print("[AudioManager] ⚠️ Invalid E4 fret number: \(fretNumber)")
                completion(nil)
                return
            } else if stringName != "E4" && (fretNumber < 0 || fretNumber > 4) {
                print("[AudioManager] ⚠️ Invalid \(stringName) fret number: \(fretNumber)")
                completion(nil)
                return
            }
        }
        
        let urlString = "https://raw.githubusercontent.com/mmaaseide23/Chordle_Assets/main/\(fileName)"
        
        guard let url = URL(string: urlString) else {
            print("[AudioManager] ⚠️ Invalid URL for: \(fileName)")
            Task { @MainActor in
                self.errorMessage = "Invalid audio URL"
            }
            completion(nil)
            return
        }
        
        print("[AudioManager] 📥 Downloading: \(fileName)")
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("[AudioManager] ⚠️ Download error for \(fileName): \(error.localizedDescription)")
                
                // Check for specific error types
                if (error as NSError).code == -50 {
                    Task { @MainActor in
                        self?.errorMessage = "Audio file configuration error. Please try another chord."
                    }
                } else {
                    Task { @MainActor in
                        self?.errorMessage = "Network error. Please check connection."
                    }
                }
                
                completion(nil)
                return
            }
            
            // Validate HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    print("[AudioManager] ⚠️ HTTP error \(httpResponse.statusCode) for \(fileName)")
                    if httpResponse.statusCode == 404 {
                        Task { @MainActor in
                            self?.errorMessage = "Audio file not found: \(fileName)"
                        }
                    }
                    completion(nil)
                    return
                }
            }
            
            guard let data = data, !data.isEmpty else {
                print("[AudioManager] ⚠️ No data received for \(fileName)")
                Task { @MainActor in
                    self?.errorMessage = "Empty audio file received"
                }
                completion(nil)
                return
            }
            
            // Validate it's actually audio data (m4a should start with specific bytes)
            let headerBytes = data.prefix(4)
            // M4A files typically start with "ftyp" at byte offset 4
            // We'll just check that we have reasonable data
            if data.count < 100 {
                print("[AudioManager] ⚠️ Suspiciously small audio file: \(data.count) bytes")
                Task { @MainActor in
                    self?.errorMessage = "Invalid audio data received"
                }
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
