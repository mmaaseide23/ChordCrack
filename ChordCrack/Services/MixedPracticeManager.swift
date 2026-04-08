import SwiftUI
import Foundation

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

    private(set) var gameCompleted = false

    enum GameState {
        case waiting
        case playing
        case answered
        case completed
    }

    var isGameCompleted: Bool {
        return gameCompleted && currentRound > totalRounds
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
        case 3, 4:
            return "Choose your audio style"
        case 5:
            return "Mixed up finger positions shown!"
        case 6:
            return "One finger position revealed!"
        default:
            return "Listen carefully..."
        }
    }

    var currentHintType: GameManager.HintType {
        switch currentAttempt {
        case 1, 2: return .chordNoFingers
        case 3, 4, 5, 6: return .audioOptions
        default: return .chordNoFingers
        }
    }

    var showAudioOptions: Bool {
        return currentAttempt >= 3 && currentAttempt <= 6
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
        gameCompleted = false
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
            gameCompleted = true
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

            if currentAttempt == 6 && shouldProvideFingerHints() {
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

    func updateSelectedAudioOption(_ option: GameManager.AudioOption) {
        selectedAudioOption = option
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
