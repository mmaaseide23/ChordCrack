import SwiftUI
import Foundation

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

    var hintDescription: String {
        switch currentAttempt {
        case 1, 2:
            return "Full chord - no hints yet"
        case 3, 4, 5, 6:
            return "Choose your audio style"
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

    func startPracticeSession(for category: ChordCategory) {
        practiceCategory = category
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

    func startNewRound() {
        guard currentRound <= totalRounds else {
            gameState = .completed
            gameCompleted = true
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

            if currentAttempt == 6 {
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
