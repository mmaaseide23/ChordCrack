import Foundation
import Combine

/// Core game management system handling game state, scoring, and progression
/// Enforces daily challenge restriction to basic major/minor chords only
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
    private let maxRounds = 5 // FIXED: Set to 5 rounds consistently
    
    // MARK: - Enums
    
    enum GameState {
        case waiting
        case playing
        case answered
        case gameOver
    }
    
    enum HintType {
        case chordNoFingers     // Attempts 1-2: Full chord, no finger display
        case chordSlow          // Attempt 3: Slower chord
        case individualStrings  // Attempt 4: Each string separately
        case audioOptions       // Attempt 5: User chooses audio + jumbled fingers
        case singleFingerReveal // Attempt 6: One correct finger shown
    }
    
    enum AudioOption: String, CaseIterable {
        case chord = "Chord"
        case arpeggiated = "Arpeggio"
        case individual = "Individual"
        case bass = "Bass"
        case treble = "Treble"
    }
    
    // MARK: - Computed Properties
    
    var currentHintType: HintType {
        switch currentAttempt {
        case 1, 2: return .chordNoFingers
        case 3: return .chordSlow
        case 4: return .individualStrings
        case 5: return .audioOptions
        case 6: return .singleFingerReveal
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
            return "Choose what to hear"
        case .singleFingerReveal:
            return "One finger position revealed"
        }
    }
    
    var challengeProgress: Double {
        return Double(currentRound - 1) / Double(maxRounds)
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
    }
    
    func nextRound() {
        currentRound += 1
        startNewRound()
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
    }
    
    private func startNewRound() {
        guard currentRound <= maxRounds else {
            endGame()
            return
        }
        
        // CRITICAL: Only use basic chords for daily puzzle (A-G major/minor)
        currentChord = ChordType.basicChords.randomElement()
        selectedChord = nil
        currentAttempt = 1
        attempts = Array(repeating: nil, count: maxAttempts)
        gameState = .playing
        totalQuestions += 1
        
        // Reset hint states
        jumbledFingerPositions = []
        revealedFingerIndex = -1
        
        // Reset audio manager for new attempt
        audioManager?.resetForNewAttempt()
    }
    
    private func handleCorrectGuess() {
        let points = calculatePoints()
        score += points
        streak += 1
        bestStreak = max(bestStreak, streak)
        totalCorrect += 1
        gameState = .answered
        
        scheduleNextRound()
    }
    
    private func handleIncorrectGuess() {
        currentAttempt += 1
        streak = 0 // Reset streak on wrong answer
        
        // Reset audio manager for new attempt
        audioManager?.resetForNewAttempt()
        
        // Provide hints based on attempt number
        switch currentAttempt {
        case 5:
            generateJumbledFingerPositions()
        case 6:
            revealRandomFingerPosition()
        default:
            break
        }
        
        if currentAttempt > maxAttempts {
            gameState = .answered
            scheduleNextRound()
        }
    }
    
    private func calculatePoints() -> Int {
        // More points for fewer attempts (max 60, min 10)
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
        
        // Record game session with UserDataManager - now properly tracks all stats
        if let userDataManager = userDataManager {
            GameStatsTracker.recordSession(
                userDataManager: userDataManager,
                gameType: GameTypeConstants.dailyChallenge,
                score: score,
                streak: bestStreak,
                correctAnswers: totalCorrect,
                totalQuestions: totalQuestions
            )
        }
    }
    
    private func generateJumbledFingerPositions() {
        guard let chord = currentChord else { return }
        let correctPositions = chord.fingerPositions.map { $0.fret }
        jumbledFingerPositions = correctPositions.shuffled()
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
    
    /// Thread-safe method to update game state
    func updateGameState(_ newState: GameState) {
        gameState = newState
    }
    
    /// Thread-safe method to update score
    func updateScore(_ newScore: Int) {
        score = newScore
    }
}
