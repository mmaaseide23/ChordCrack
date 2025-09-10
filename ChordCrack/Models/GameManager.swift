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
        var gameType: String = GameTypeConstants.dailyChallenge
        
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
        
        audioManager?.resetForNewAttempt()
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
        
        let finalStats = validateAndPrepareStats()
        recordGameSession(with: finalStats)
    }
    
    private func validateAndPrepareStats() -> (score: Int, bestStreak: Int, correctAnswers: Int, totalQuestions: Int) {
        let finalScore = max(score, currentGameStats.totalScore)
        let finalBestStreak = max(bestStreak, currentGameStats.bestStreakInSession)
        let finalCorrectAnswers = max(totalCorrect, currentGameStats.correctAnswers)
        let finalTotalQuestions = max(totalQuestions, currentGameStats.totalQuestions)
        
        guard finalTotalQuestions > 0, finalCorrectAnswers <= finalTotalQuestions else {
            return (score: max(finalScore, 0), bestStreak: max(finalBestStreak, 0), correctAnswers: 1, totalQuestions: max(finalTotalQuestions, 1))
        }
        
        return (score: finalScore, bestStreak: finalBestStreak, correctAnswers: finalCorrectAnswers, totalQuestions: finalTotalQuestions)
    }
    
    private func recordGameSession(with stats: (score: Int, bestStreak: Int, correctAnswers: Int, totalQuestions: Int)) {
        guard let userDataManager = userDataManager else { return }
        
        userDataManager.recordGameSession(
            score: stats.score,
            streak: stats.bestStreak,
            correctAnswers: stats.correctAnswers,
            totalQuestions: stats.totalQuestions,
            gameType: GameTypeConstants.dailyChallenge
        )
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
        score = newScore
    }
}

/// Extension to your existing GameManager for social challenge features
extension GameManager {
    
    // MARK: - Challenge Properties
    
    private static var _challengeId: String = ""
    private static var _challengeType: SocialChallengeType = .dailyChallenge
    private static var _socialManager: SocialManager?
    
    var challengeId: String {
        get { Self._challengeId }
        set { Self._challengeId = newValue }
    }
    
    var challengeType: SocialChallengeType {
        get { Self._challengeType }
        set { Self._challengeType = newValue }
    }
    
    var socialManager: SocialManager? {
        get { Self._socialManager }
        set { Self._socialManager = newValue }
    }
    
    // MARK: - Challenge Setup
    
    func setupChallenge(challengeId: String, type: SocialChallengeType, socialManager: SocialManager) {
        self.challengeId = challengeId
        self.challengeType = type
        self.socialManager = socialManager
    }
    
    func startChallengeGame() {
        // Use your existing game start logic
        startNewGame()
    }
    
    // MARK: - Challenge Completion
    
    func completeChallengeGame() {
        guard !challengeId.isEmpty, let socialManager = socialManager else {
            return
        }
        
        // Submit challenge score using existing game stats
        Task {
            let success = await socialManager.submitChallengeScore(
                challengeId: challengeId,
                score: score,
                correctAnswers: totalCorrect,
                totalQuestions: totalQuestions
            )
            
            await MainActor.run {
                if success {
                    print("Challenge score submitted successfully")
                } else {
                    print("Failed to submit challenge score")
                }
            }
        }
    }
    
    // Override your existing endGame to handle challenges
    func endChallengeGame() {
        // Call your existing end game logic first
        gameState = .gameOver
        isGameActive = false
        totalGames += 1
        
        // Then handle challenge completion
        completeChallengeGame()
    }
}
