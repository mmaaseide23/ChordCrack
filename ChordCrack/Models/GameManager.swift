import Foundation
import Combine

/// Core game management system handling game state, scoring, and progression
@MainActor
final class GameManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentRound = 1
    @Published var score = 0
    @Published var isGameActive = false
    @Published var currentChord: ChordType?
    @Published var selectedChord: ChordType?
    @Published var gameState: GameState = .waiting
    @Published var streak = 0
    @Published var totalGames = 0
    @Published var currentAttempt = 1
    @Published var maxAttempts = 6
    @Published var attempts: [ChordType?] = []
    @Published var selectedAudioOption: AudioOption = .chord
    @Published var jumbledFingerPositions: [Int] = []
    @Published var revealedFingerIndex: Int = -1
    
    // MARK: - Statistics Tracking
    @Published var bestStreak = 0
    @Published var totalCorrect = 0
    @Published var totalQuestions = 0
    
    // MARK: - Private Properties
    
    private var audioManager: AudioManager?
    private var userDataManager: UserDataManager?
    private let maxRounds = 5
    private var currentGameStats: GameSessionStats = GameSessionStats()
    private var gameCompleted = false // Track if game was fully completed
    private var gameSessionId = UUID() // Unique ID for each game session
    
    // MARK: - Persistence Keys
    private struct PersistenceKeys {
        static let currentRound = "GameManager.currentRound"
        static let score = "GameManager.score"
        static let streak = "GameManager.streak"
        static let totalCorrect = "GameManager.totalCorrect"
        static let totalQuestions = "GameManager.totalQuestions"
        static let isGameActive = "GameManager.isGameActive"
        static let gameSessionId = "GameManager.gameSessionId"
    }
    
    // MARK: - Enums
    
    enum GameState {
        case waiting
        case playing
        case answered
        case gameOver
    }
    
    enum HintType {
        case chordNoFingers
        case chordSlow
        case individualStrings
        case audioOptions
        case singleFingerReveal
    }
    
    enum AudioOption: String, CaseIterable {
        case chord = "Full Chord"
        case individual = "Individual Strings"
        case bass = "Bass Notes"
        case treble = "Treble Notes"
    }
    
    // MARK: - Game Session Stats Tracking
    private struct GameSessionStats {
        var startTime: Date?
        var totalQuestions: Int = 0
        var correctAnswers: Int = 0
        var currentStreak: Int = 0
        var bestStreakInSession: Int = 0
        var totalScore: Int = 0
        var gameType: String = "dailyChallenge"  // Direct string instead of GameTypeConstants
        
        mutating func reset() {
            startTime = Date()
            totalQuestions = 0
            correctAnswers = 0
            currentStreak = 0
            bestStreakInSession = 0
            totalScore = 0
        }
        
        mutating func recordCorrectAnswer(score: Int, streak: Int) {
            correctAnswers += 1
            currentStreak = streak
            bestStreakInSession = max(bestStreakInSession, streak)
            totalScore += score
        }
        
        mutating func recordIncorrectAnswer() {
            currentStreak = 0
        }
        
        mutating func addQuestion() {
            totalQuestions += 1
        }
    }
    
    // MARK: - Computed Properties
    
    var currentHintType: HintType {
        switch currentAttempt {
        case 1, 2: return .chordNoFingers
        case 3, 4, 5, 6: return .audioOptions // Changed to allow audio options for attempts 3-6
        default: return .chordNoFingers
        }
    }
    
    var hintDescription: String {
        switch currentHintType {
        case .chordNoFingers:
            return "Listen to the full chord"
        case .chordSlow:
            return "Chord played arpeggiated"
        case .individualStrings:
            return "Each string played separately"
        case .audioOptions:
            if currentAttempt == 5 {
                return "Mixed up finger positions shown!"
            } else if currentAttempt == 6 {
                return "One finger position revealed!"
            } else {
                return "Choose what to hear"
            }
        case .singleFingerReveal:
            return "One finger position revealed"
        }
    }
    
    var challengeProgress: Double {
        return Double(currentRound - 1) / Double(maxRounds)
    }
    
    var showAudioOptions: Bool {
        return currentAttempt >= 3 && currentAttempt <= 6
    }
    
    // Public computed property to check if game is completed
    var isGameCompleted: Bool {
        return gameCompleted
    }
    
    // MARK: - Initialization
    
    init() {
        loadGameState()
    }
    
    // MARK: - Public Methods
    
    func setAudioManager(_ audioManager: AudioManager) {
        self.audioManager = audioManager
    }
    
    func setUserDataManager(_ userDataManager: UserDataManager) {
        self.userDataManager = userDataManager
    }
    
    func startNewGame() {
        resetGameState()
        startNewRound()
        saveGameState()
    }
    
    func resumeGame() {
        if isGameActive && currentRound <= maxRounds {
            // Resume from saved state
            startNewRound()
        } else {
            startNewGame()
        }
    }
    
    func submitGuess(_ guess: ChordType) {
        guard gameState == .playing, currentAttempt <= maxAttempts else { return }
        
        selectedChord = guess
        attempts[currentAttempt - 1] = guess
        
        if guess == currentChord {
            handleCorrectGuess()
        } else {
            handleIncorrectGuess()
        }
        
        saveGameState()
    }
    
    func nextRound() {
        currentRound += 1
        startNewRound()
        saveGameState()
    }
    
    func updateSelectedAudioOption(_ option: AudioOption) {
        selectedAudioOption = option
    }
    
    // MARK: - Private Methods
    
    private func resetGameState() {
        currentRound = 1
        score = 0
        streak = 0
        bestStreak = 0
        totalCorrect = 0
        totalQuestions = 0
        isGameActive = true
        gameState = .waiting
        selectedAudioOption = .chord
        gameCompleted = false
        gameSessionId = UUID() // New session ID for new game
        currentGameStats.reset()
    }
    
    private func startNewRound() {
        guard currentRound <= maxRounds else {
            endGame()
            return
        }
        
        currentChord = ChordType.basicChords.randomElement()
        selectedChord = nil
        currentAttempt = 1
        attempts = Array(repeating: nil, count: maxAttempts)
        gameState = .playing
        selectedAudioOption = .chord // Reset to default for each round
        
        currentGameStats.addQuestion()
        totalQuestions += 1
        
        // Reset hint states
        jumbledFingerPositions = []
        revealedFingerIndex = -1
        
        // Reset audio manager for new round
        audioManager?.resetForNewRound()
    }
    
    private func handleCorrectGuess() {
        let points = calculatePoints()
        score += points
        streak += 1
        bestStreak = max(bestStreak, streak)
        totalCorrect += 1
        gameState = .answered
        
        currentGameStats.recordCorrectAnswer(score: points, streak: streak)
        
        scheduleNextRound()
    }
    
    private func handleIncorrectGuess() {
        currentAttempt += 1
        streak = 0
        
        currentGameStats.recordIncorrectAnswer()
        audioManager?.resetForNewAttempt()
        
        // Show jumbled fingers on attempt 5, finger reveal on attempt 6
        if currentAttempt == 5 {
            generateJumbledFingerPositions()
        } else if currentAttempt == 6 {
            revealRandomFingerPosition()
        }
        
        if currentAttempt > maxAttempts {
            gameState = .answered
            scheduleNextRound()
        }
    }
    
    private func calculatePoints() -> Int {
        return max(60 - (currentAttempt - 1) * 10, 10)
    }
    
    private func scheduleNextRound() {
        let delay = gameState == .answered && selectedChord == currentChord ? 2.0 : 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.nextRound()
        }
    }
    
    private func endGame() {
        gameState = .gameOver
        isGameActive = false
        totalGames += 1
        gameCompleted = true // Mark game as completed
        
        // Clear saved state when game ends
        clearSavedGameState()
        
        // Only record stats for fully completed games
        let finalStats = validateAndPrepareStats()
        recordGameSession(with: finalStats)
    }
    
    private func validateAndPrepareStats() -> (score: Int, bestStreak: Int, correctAnswers: Int, totalQuestions: Int) {
        // Ensure score is never negative
        let finalScore = max(0, max(score, currentGameStats.totalScore))
        let finalBestStreak = max(0, max(bestStreak, currentGameStats.bestStreakInSession))
        let finalCorrectAnswers = max(0, min(totalCorrect, totalQuestions))
        let finalTotalQuestions = max(1, totalQuestions)
        
        return (score: finalScore, bestStreak: finalBestStreak, correctAnswers: finalCorrectAnswers, totalQuestions: finalTotalQuestions)
    }
    
    private func recordGameSession(with stats: (score: Int, bestStreak: Int, correctAnswers: Int, totalQuestions: Int)) {
        // Only record if game was completed
        guard gameCompleted, let userDataManager = userDataManager else {
            print("[GameManager] Game not completed or no UserDataManager, skipping stats recording")
            return
        }
        
        print("[GameManager] Recording completed game session - Score: \(stats.score)")
        
        userDataManager.recordGameSession(
            score: stats.score,
            streak: stats.bestStreak,
            correctAnswers: stats.correctAnswers,
            totalQuestions: stats.totalQuestions,
            gameType: "dailyChallenge"  // Direct string instead of GameTypeConstants
        )
    }
    
    // MARK: - Game State Persistence
    
    private func saveGameState() {
        UserDefaults.standard.set(currentRound, forKey: PersistenceKeys.currentRound)
        UserDefaults.standard.set(max(0, score), forKey: PersistenceKeys.score)
        UserDefaults.standard.set(max(0, streak), forKey: PersistenceKeys.streak)
        UserDefaults.standard.set(max(0, totalCorrect), forKey: PersistenceKeys.totalCorrect)
        UserDefaults.standard.set(max(0, totalQuestions), forKey: PersistenceKeys.totalQuestions)
        UserDefaults.standard.set(isGameActive, forKey: PersistenceKeys.isGameActive)
        UserDefaults.standard.set(gameSessionId.uuidString, forKey: PersistenceKeys.gameSessionId)
    }
    
    private func loadGameState() {
        // Check if there's a saved game session
        if let savedSessionId = UserDefaults.standard.string(forKey: PersistenceKeys.gameSessionId),
           UserDefaults.standard.bool(forKey: PersistenceKeys.isGameActive) {
            
            // Load saved state
            currentRound = UserDefaults.standard.integer(forKey: PersistenceKeys.currentRound)
            score = max(0, UserDefaults.standard.integer(forKey: PersistenceKeys.score))
            streak = max(0, UserDefaults.standard.integer(forKey: PersistenceKeys.streak))
            totalCorrect = max(0, UserDefaults.standard.integer(forKey: PersistenceKeys.totalCorrect))
            totalQuestions = max(0, UserDefaults.standard.integer(forKey: PersistenceKeys.totalQuestions))
            isGameActive = true
            gameSessionId = UUID(uuidString: savedSessionId) ?? UUID()
            
            // Validate loaded state
            if currentRound < 1 || currentRound > maxRounds {
                currentRound = 1
            }
        }
    }
    
    private func clearSavedGameState() {
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.currentRound)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.score)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.streak)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.totalCorrect)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.totalQuestions)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.isGameActive)
        UserDefaults.standard.removeObject(forKey: PersistenceKeys.gameSessionId)
    }
    
    private func generateJumbledFingerPositions() {
        guard let chord = currentChord else { return }
        
        // Get all finger positions that are not open strings (fret > 0)
        let fingeredPositions = chord.fingerPositions.filter { $0.fret > 0 }
        
        // Get just the fret numbers and shuffle them
        let fretPositions = fingeredPositions.map { $0.fret }.shuffled()
        
        // Create enough random string positions (0-5) for each fret
        var availableStrings = Array(0...5).shuffled()
        
        // Ensure we have enough strings by repeating if necessary
        while availableStrings.count < fretPositions.count {
            availableStrings.append(contentsOf: Array(0...5).shuffled())
        }
        
        // Take only as many strings as we have frets, ensuring no duplicates in the first set
        availableStrings = Array(Set(availableStrings.prefix(fretPositions.count)))
        
        // If we still don't have enough unique strings, add more
        while availableStrings.count < fretPositions.count {
            let missingCount = fretPositions.count - availableStrings.count
            let additionalStrings = Array(0...5).shuffled().prefix(missingCount)
            availableStrings.append(contentsOf: additionalStrings)
        }
        
        // Store the jumbled fret positions
        jumbledFingerPositions = fretPositions
        
        print("[GameManager] Generated \(jumbledFingerPositions.count) jumbled finger positions: \(jumbledFingerPositions)")
        print("[GameManager] Original positions: \(fingeredPositions.map { "String \($0.string) Fret \($0.fret)" })")
    }
    
    private func revealRandomFingerPosition() {
        guard let chord = currentChord else { return }
        let fingerPositions = chord.fingerPositions.filter { $0.fret > 0 }
        if !fingerPositions.isEmpty {
            revealedFingerIndex = Int.random(in: 0..<fingerPositions.count)
        }
    }
}

// MARK: - Thread Safety Extension

extension GameManager {
    func updateGameState(_ newState: GameState) {
        gameState = newState
    }
    
    func updateScore(_ newScore: Int) {
        score = max(0, newScore)
        saveGameState()
    }
}
