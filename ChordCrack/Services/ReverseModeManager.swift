import Foundation
import SwiftUI
import Combine

/// Core manager for Reverse Mode gameplay
@MainActor
final class ReverseModeManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var gameState: GameState = .waiting
    @Published var currentRound = 1
    @Published var totalRounds = 10
    @Published var score = 0
    @Published var currentStreak = 0
    @Published var bestStreak = 0
    @Published var totalCorrect = 0
    @Published var totalQuestions = 0
    @Published var currentAttempt = 1
    @Published var maxAttempts = 6
    
    // Target chord and user input
    @Published var targetChord: ChordType?
    @Published var placedFingers: Set<FingerPosition> = []
    @Published var openStrings: Set<Int> = []
    @Published var mutedStrings: Set<Int> = []
    
    // Hints
    @Published var hasUsedSoundHint = false
    @Published var hasUsedTheoryHint = false
    @Published var showTheoryHints = false
    @Published var isAnswerCorrect = false
    
    // Game mode (matches regular game modes)
    @Published var gameMode: GameType = .dailyChallenge
    @Published var practiceCategory: ChordCategory = .basic
    
    // Feedback
    @Published var showingCorrectPositions = false
    @Published var correctPositions: [(string: String, fret: Int)] = []
    @Published var incorrectPositions: Set<FingerPosition> = []
    @Published var missingPositions: Set<FingerPosition> = []
    
    // MARK: - Private Properties
    
    private var audioManager: AudioManager?
    private var userDataManager: UserDataManager?
    private var gameCompleted = false
    private var gameSessionId = UUID()
    private var currentGameStats = GameSessionStats()
    
    // MARK: - Enums
    
    enum GameState {
        case waiting
        case playing
        case answered
        case completed
        case paused
    }
    
    // MARK: - Game Session Stats
    
    struct GameSessionStats {
        var startTime: Date?
        var totalQuestions: Int = 0
        var correctAnswers: Int = 0
        var currentStreak: Int = 0
        var bestStreakInSession: Int = 0
        var totalScore: Int = 0
        var totalHintsUsed: Int = 0
        var totalSoundHints: Int = 0
        var totalTheoryHints: Int = 0
        
        mutating func reset() {
            startTime = Date()
            totalQuestions = 0
            correctAnswers = 0
            currentStreak = 0
            bestStreakInSession = 0
            totalScore = 0
            totalHintsUsed = 0
            totalSoundHints = 0
            totalTheoryHints = 0
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
    }
    
    // MARK: - Computed Properties
    
    var isGameCompleted: Bool {
        return gameCompleted && currentRound > totalRounds
    }
    
    var progressPercentage: Double {
        return Double(currentRound - 1) / Double(totalRounds)
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialization
    }
    
    // MARK: - Public Methods
    
    func setAudioManager(_ manager: AudioManager) {
        self.audioManager = manager
    }
    
    func setUserDataManager(_ manager: UserDataManager) {
        self.userDataManager = manager
    }
    
    func startNewGame(mode: GameType = .dailyChallenge) {
        gameMode = mode
        determineChordPool()
        resetGameState()
        loadNextChord()
    }
    
    func startPracticeSession(for category: ChordCategory) {
        practiceCategory = category
        gameMode = gameModeForCategory(category)
        resetGameState()
        loadNextChord()
    }
    
    func loadNextChord() {
        guard currentRound <= totalRounds else {
            endGame()
            return
        }
        
        // Select chord based on game mode
        let availableChords = getChordsForCurrentMode()
        targetChord = availableChords.randomElement()
        
        // Reset for new round
        clearBoard()
        hasUsedSoundHint = false
        hasUsedTheoryHint = false
        showTheoryHints = false
        currentAttempt = 1
        gameState = .playing
        showingCorrectPositions = false
        correctPositions = []
        incorrectPositions = []
        missingPositions = []
        
        currentGameStats.totalQuestions += 1
        totalQuestions += 1
    }
    
    func clearBoard() {
        withAnimation(.spring(response: 0.3)) {
            placedFingers.removeAll()
            openStrings.removeAll()
            mutedStrings.removeAll()
        }
    }
    
    func submitAnswer() {
        guard gameState == .playing, currentAttempt <= maxAttempts else { return }
        
        isAnswerCorrect = checkAnswer()
        
        if isAnswerCorrect {
            handleCorrectAnswer()
        } else {
            handleIncorrectAnswer()
        }
    }
    
    func useSoundHint() {
        guard !hasUsedSoundHint else { return }
        
        hasUsedSoundHint = true
        currentGameStats.totalSoundHints += 1
        currentGameStats.totalHintsUsed += 1
        
        // Play the chord audio
        if let chord = targetChord {
            audioManager?.playChord(chord)
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func toggleTheoryHint() {
        showTheoryHints.toggle()
        if showTheoryHints && !hasUsedTheoryHint {
            hasUsedTheoryHint = true
            currentGameStats.totalTheoryHints += 1
            currentGameStats.totalHintsUsed += 1
        }
    }
    
    func nextRound() {
        currentRound += 1
        loadNextChord()
    }
    
    func pauseGame() {
        if gameState == .playing {
            gameState = .paused
        }
    }
    
    func resumeGame() {
        if gameState == .paused {
            gameState = .playing
        }
    }
    
    // MARK: - Fretboard Interaction
    
    func toggleFinger(string: Int, fret: Int) {
        guard gameState == .playing else { return }
        
        withAnimation(.spring(response: 0.3)) {
            let position = FingerPosition(string: string, fret: fret)
            
            // Remove any other finger on this string
            placedFingers = placedFingers.filter { $0.string != string }
            
            // Add new position if not already there
            if !placedFingers.contains(position) {
                placedFingers.insert(position)
                
                // Remove open/muted state when placing a finger
                openStrings.remove(string)
                mutedStrings.remove(string)
            }
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func toggleStringState(_ string: Int) {
        guard gameState == .playing else { return }
        
        withAnimation(.spring(response: 0.3)) {
            // Remove any fingers on this string
            placedFingers = placedFingers.filter { $0.string != string }
            
            if openStrings.contains(string) {
                openStrings.remove(string)
                mutedStrings.insert(string)
            } else if mutedStrings.contains(string) {
                mutedStrings.remove(string)
                // String becomes unfretted (no state)
            } else {
                openStrings.insert(string)
            }
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Private Methods
    
    private func resetGameState() {
        currentRound = 1
        score = 0
        currentStreak = 0
        bestStreak = 0
        totalCorrect = 0
        totalQuestions = 0
        gameState = .waiting
        gameCompleted = false
        gameSessionId = UUID()
        currentGameStats.reset()
    }
    
    private func determineChordPool() {
        switch gameMode {
        case .dailyChallenge, .basicPractice:
            practiceCategory = .basic
        case .powerPractice:
            practiceCategory = .power
        case .barrePractice:
            practiceCategory = .barre
        case .bluesPractice:
            practiceCategory = .blues
        case .mixedPractice:
            // Will use all categories
            practiceCategory = .basic
        default:
            practiceCategory = .basic
        }
    }
    
    private func getChordsForCurrentMode() -> [ChordType] {
        switch gameMode {
        case .dailyChallenge, .basicPractice:
            return ChordType.basicChords
        case .powerPractice:
            return ChordType.powerChords
        case .barrePractice:
            return ChordType.barreChords
        case .bluesPractice:
            return ChordType.bluesChords
        case .mixedPractice:
            return ChordType.allCases
        default:
            return ChordType.basicChords
        }
    }
    
    private func gameModeForCategory(_ category: ChordCategory) -> GameType {
        switch category {
        case .basic: return .basicPractice
        case .power: return .powerPractice
        case .barre: return .barrePractice
        case .blues: return .bluesPractice
        }
    }
    
    private func checkAnswer() -> Bool {
        guard let chord = targetChord else { return false }
        
        let correctPositions = chord.fingerPositions
        var isCorrect = true
        
        // Convert correct positions to comparable format
        let correctPositionsSet = Set(correctPositions.map { position in
            FingerPosition(string: stringNameToIndex(position.string), fret: position.fret)
        })
        
        // Check if all correct positions are placed
        for correctPos in correctPositionsSet {
            if !placedFingers.contains(correctPos) {
                isCorrect = false
                missingPositions.insert(correctPos)
            }
        }
        
        // Check for incorrect positions
        for placedPos in placedFingers {
            if !correctPositionsSet.contains(placedPos) {
                isCorrect = false
                incorrectPositions.insert(placedPos)
            }
        }
        
        // Store correct positions for display
        self.correctPositions = correctPositions
        
        return isCorrect && placedFingers.count == correctPositions.count
    }
    
    private func stringNameToIndex(_ stringName: String) -> Int {
        switch stringName {
        case "E4": return 0
        case "B4": return 1
        case "G3": return 2
        case "D3": return 3
        case "A3": return 4
        case "E2": return 5
        default: return 0
        }
    }
    
    private func handleCorrectAnswer() {
        let points = calculatePoints()
        score += points
        currentStreak += 1
        bestStreak = max(bestStreak, currentStreak)
        totalCorrect += 1
        gameState = .answered
        
        currentGameStats.recordCorrectAnswer(score: points, streak: currentStreak)
        
        // Show visual feedback
        showingCorrectPositions = true
        
        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Auto-advance after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.currentRound < self.totalRounds {
                self.nextRound()
            } else {
                self.endGame()
            }
        }
    }
    
    private func handleIncorrectAnswer() {
        currentStreak = 0
        currentAttempt += 1
        
        currentGameStats.recordIncorrectAnswer()
        
        // Show feedback
        showingCorrectPositions = true
        
        // Haptic feedback
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        
        if currentAttempt > maxAttempts {
            gameState = .answered
            
            // Auto-advance after longer delay for study
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if self.currentRound < self.totalRounds {
                    self.nextRound()
                } else {
                    self.endGame()
                }
            }
        } else {
            // Reset feedback after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showingCorrectPositions = false
                self.incorrectPositions.removeAll()
                self.missingPositions.removeAll()
            }
        }
    }
    
    func calculatePoints() -> Int {
        var points = 60
        
        // Deduct for attempts
        points -= (currentAttempt - 1) * 10
        
        // Deduct for hints
        if hasUsedSoundHint { points -= 10 }
        if hasUsedTheoryHint { points -= 15 }
        
        return max(points, 10)
    }
    
    private func endGame() {
        gameState = .completed
        gameCompleted = true
        
        // Record session with UserDataManager
        recordGameSession()
    }
    
    private func recordGameSession() {
        guard gameCompleted, let userDataManager = userDataManager else { return }
        
        userDataManager.recordReverseModeSession(
            score: score,
            streak: bestStreak,
            correctAnswers: totalCorrect,
            totalQuestions: totalQuestions,
            gameType: gameMode.rawValue,
            soundHintsUsed: currentGameStats.totalSoundHints,
            theoryHintsUsed: currentGameStats.totalTheoryHints
        )
    }
}

// MARK: - GameType Extension for Reverse Mode

extension GameType {
    var rawValue: String {
        switch self {
        case .dailyChallenge: return "reverseDailyChallenge"
        case .basicPractice: return "reverseBasicPractice"
        case .barrePractice: return "reverseBarrePractice"
        case .bluesPractice: return "reverseBluesPractice"
        case .powerPractice: return "reversePowerPractice"
        case .mixedPractice: return "reverseMixedPractice"
        case .speedRound: return "reverseSpeedRound"
        }
    }
}
