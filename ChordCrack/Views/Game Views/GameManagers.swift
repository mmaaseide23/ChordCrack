import SwiftUI

// MARK: - Practice Manager
class PracticeManager: ObservableObject {
    @Published var currentRound = 1
    @Published var totalRounds = 5
    @Published var score = 0
    @Published var currentChord: ChordType?
    @Published var selectedChord: ChordType?
    @Published var gameState: GameState = .waiting
    @Published var currentAttempt = 1
    @Published var maxAttempts = 6
    @Published var attempts: [ChordType?] = []
    @Published var jumbledFingerPositions: [Int] = []
    @Published var revealedFingerIndex: Int = -1
    @Published var practiceCategory: ChordCategory = .basic
    @Published var selectedAudioOption: GameManager.AudioOption = .chord
    @Published var currentStreak = 0
    @Published var bestStreak = 0
    @Published var totalCorrect = 0
    @Published var totalQuestions = 0
    
    enum GameState {
        case waiting
        case playing
        case answered
        case completed
    }
    
    var hintDescription: String {
        switch currentAttempt {
        case 1, 2:
            return "Full chord - no hints yet"
        case 3:
            return "Same chord played slower"
        case 4:
            return "Individual strings separated"
        case 5:
            return "Choose your audio style"
        case 6:
            return "One finger position revealed!"
        default:
            return "Listen carefully..."
        }
    }
    
    var currentHintType: GameManager.HintType {
        switch currentAttempt {
        case 1, 2: return .chordNoFingers
        case 3: return .chordSlow
        case 4: return .individualStrings
        case 5: return .audioOptions
        case 6: return .singleFingerReveal
        default: return .chordNoFingers
        }
    }
    
    func startPracticeSession(for category: ChordCategory) {
        practiceCategory = category
        currentRound = 1
        score = 0
        currentStreak = 0
        bestStreak = 0
        totalCorrect = 0
        totalQuestions = 0
        gameState = .waiting
        startNewRound()
    }
    
    func startNewRound() {
        guard currentRound <= totalRounds else {
            gameState = .completed
            return
        }
        
        let availableChords: [ChordType]
        switch practiceCategory {
        case .basic:
            availableChords = ChordType.basicChords
        case .barre:
            availableChords = ChordType.barreChords
        case .blues:
            availableChords = ChordType.bluesChords
        case .power:
            availableChords = ChordType.powerChords
        }
        
        currentChord = availableChords.randomElement()
        selectedChord = nil
        currentAttempt = 1
        attempts = Array(repeating: nil, count: maxAttempts)
        gameState = .playing
        jumbledFingerPositions = []
        revealedFingerIndex = -1
        selectedAudioOption = .chord
        totalQuestions += 1
    }
    
    func submitGuess(_ guess: ChordType) {
        guard gameState == .playing, currentAttempt <= maxAttempts else { return }
        
        selectedChord = guess
        attempts[currentAttempt - 1] = guess
        
        if guess == currentChord {
            let points = max(60 - (currentAttempt - 1) * 10, 10)
            score += points
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            totalCorrect += 1
            gameState = .answered
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.nextRound()
            }
        } else {
            currentStreak = 0
            currentAttempt += 1
            
            if currentAttempt == 4 {
                generateJumbledFingerPositions()
            } else if currentAttempt == 6 {
                revealRandomFingerPosition()
            }
            
            if currentAttempt > maxAttempts {
                gameState = .answered
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.nextRound()
                }
            }
        }
    }
    
    func nextRound() {
        currentRound += 1
        startNewRound()
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

// MARK: - Mixed Practice Manager
class MixedPracticeManager: ObservableObject {
    @Published var currentRound = 1
    @Published var totalRounds = 5
    @Published var score = 0
    @Published var currentChord: ChordType?
    @Published var selectedChord: ChordType?
    @Published var gameState: GameState = .waiting
    @Published var currentAttempt = 1
    @Published var maxAttempts = 6
    @Published var attempts: [ChordType?] = []
    @Published var jumbledFingerPositions: [Int] = []
    @Published var revealedFingerIndex: Int = -1
    @Published var currentCategory: ChordCategory?
    @Published var difficultyProgression: [ChordCategory] = []
    @Published var currentStreak = 0
    @Published var bestStreak = 0
    @Published var totalCorrect = 0
    @Published var totalQuestions = 0
    @Published var selectedAudioOption: GameManager.AudioOption = .chord
    
    enum GameState {
        case waiting
        case playing
        case answered
        case completed
    }
    
    var difficultyMultiplier: Int {
        switch currentCategory {
        case .basic: return 1
        case .power: return 2
        case .barre: return 3
        case .blues: return 4
        default: return 1
        }
    }
    
    var hintDescription: String {
        switch currentAttempt {
        case 1, 2:
            return "Mystery chord - no hints yet"
        case 3:
            return "Same chord played slower"
        case 4:
            return "Individual strings separated"
        case 5:
            return "Choose your audio style"
        case 6:
            return "One finger position revealed!"
        default:
            return "Listen carefully..."
        }
    }
    
    var currentHintType: GameManager.HintType {
        switch currentAttempt {
        case 1, 2: return .chordNoFingers
        case 3: return .chordSlow
        case 4: return .individualStrings
        case 5: return .audioOptions
        case 6: return .singleFingerReveal
        default: return .chordNoFingers
        }
    }
    
    func startMixedPractice() {
        setupDifficultyProgression()
        currentRound = 1
        score = 0
        currentStreak = 0
        bestStreak = 0
        totalCorrect = 0
        totalQuestions = 0
        gameState = .waiting
        startNewRound()
    }
    
    private func setupDifficultyProgression() {
        difficultyProgression = [
            .basic,
            .power,
            .basic,
            .barre,
            .blues
        ]
    }
    
    func startNewRound() {
        guard currentRound <= totalRounds else {
            gameState = .completed
            return
        }
        
        let categoryIndex = min(currentRound - 1, difficultyProgression.count - 1)
        currentCategory = difficultyProgression[categoryIndex]
        
        let availableChords: [ChordType]
        switch currentCategory {
        case .basic: availableChords = ChordType.basicChords
        case .power: availableChords = ChordType.powerChords
        case .barre: availableChords = ChordType.barreChords
        case .blues: availableChords = ChordType.bluesChords
        default: availableChords = ChordType.basicChords
        }
        
        currentChord = availableChords.randomElement()
        selectedChord = nil
        currentAttempt = 1
        attempts = Array(repeating: nil, count: maxAttempts)
        gameState = .playing
        selectedAudioOption = .chord
        
        jumbledFingerPositions = []
        revealedFingerIndex = -1
        totalQuestions += 1
    }
    
    func submitGuess(_ guess: ChordType) {
        guard gameState == .playing, currentAttempt <= maxAttempts else { return }
        
        selectedChord = guess
        attempts[currentAttempt - 1] = guess
        
        if guess == currentChord {
            let basePoints = difficultyMultiplier * 50
            let attemptPenalty = (currentAttempt - 1) * 15
            let points = max(basePoints - attemptPenalty, 15)
            score += points
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            totalCorrect += 1
            gameState = .answered
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.nextRound()
            }
        } else {
            currentStreak = 0
            currentAttempt += 1
            
            if currentAttempt == 4 && shouldProvideFingerHints() {
                generateJumbledFingerPositions()
            } else if currentAttempt == 6 && shouldProvideFingerHints() {
                revealRandomFingerPosition()
            }
            
            if currentAttempt > maxAttempts {
                gameState = .answered
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.nextRound()
                }
            }
        }
    }
    
    private func shouldProvideFingerHints() -> Bool {
        return currentCategory == .barre || currentCategory == .blues
    }
    
    func nextRound() {
        currentRound += 1
        startNewRound()
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

// MARK: - GameType Enum for Consistency
enum GameType {
    case dailyChallenge
    case basicPractice
    case barrePractice
    case bluesPractice
    case powerPractice
    case mixedPractice
    case speedRound
    
    var displayName: String {
        switch self {
        case .dailyChallenge: return "Daily Challenge"
        case .basicPractice: return "Basic Practice"
        case .barrePractice: return "Barre Practice"
        case .bluesPractice: return "Blues Practice"
        case .powerPractice: return "Power Practice"
        case .mixedPractice: return "Mixed Practice"
        case .speedRound: return "Speed Round"
        }
    }
    
    var color: Color {
        switch self {
        case .dailyChallenge: return ColorTheme.primaryGreen
        case .basicPractice: return ColorTheme.primaryGreen
        case .barrePractice: return Color.orange
        case .bluesPractice: return Color.blue
        case .powerPractice: return Color.red
        case .mixedPractice: return Color.purple
        case .speedRound: return Color.red
        }
    }
}
