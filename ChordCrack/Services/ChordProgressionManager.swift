import SwiftUI
import Foundation

/// Manages game state for the Chord Progressions mode.
/// The player listens to a 3-4 chord progression and must identify each chord in order.
@MainActor
final class ChordProgressionManager: ObservableObject {

    // MARK: - Published State

    @Published var currentRound = 1
    @Published var totalRounds = 5
    @Published var score = 0

    /// Target progression the player is trying to identify (order matters).
    @Published var currentProgression: [ChordType] = []

    /// Player's guesses, one per slot. nil = not yet filled.
    @Published var playerGuesses: [ChordType?] = []

    /// Which slot (0-based index) is currently being filled.
    @Published var activeSlotIndex: Int = 0

    @Published var gameState: GameState = .waiting
    @Published var currentAttempt = 1
    @Published var maxAttempts = 3
    @Published var currentStreak = 0
    @Published var bestStreak = 0
    @Published var totalCorrect = 0
    @Published var totalQuestions = 0

    private(set) var gameCompleted = false

    private weak var userDataManager: UserDataManager?

    // MARK: - Configuration

    /// Length of each progression (3 or 4 chords).
    let progressionLength = 4

    /// Pool of chords to choose from. Uses basic chords for broad appeal.
    private var chordPool: [ChordType] { ChordType.basicChords }

    /// Common chord progressions in popular music (encoded as indices into basicChords).
    /// Falls back to random selection if pool size doesn't match.
    private let commonPatterns: [[Int]] = [
        [0, 4, 5, 3], // I-V-vi-IV style
        [0, 5, 3, 4], // I-vi-IV-V (50s)
        [0, 3, 4, 0], // I-IV-V-I
        [5, 3, 0, 4], // vi-IV-I-V
        [0, 4, 3, 0]  // I-V-IV-I
    ]

    enum GameState {
        case waiting
        case playing
        case evaluating
        case answered
        case completed
    }

    func setUserDataManager(_ manager: UserDataManager) {
        self.userDataManager = manager
    }

    // MARK: - Lifecycle

    var isGameCompleted: Bool {
        gameCompleted && currentRound > totalRounds
    }

    func startSession() {
        currentRound = 1
        score = 0
        currentStreak = 0
        bestStreak = 0
        totalCorrect = 0
        totalQuestions = 0
        gameCompleted = false
        gameState = .waiting
        startNewRound()
    }

    func startNewRound() {
        guard currentRound <= totalRounds else {
            gameState = .completed
            gameCompleted = true
            return
        }

        currentProgression = generateProgression()
        playerGuesses = Array(repeating: nil, count: currentProgression.count)
        activeSlotIndex = 0
        currentAttempt = 1
        gameState = .playing
        totalQuestions += 1
    }

    private func generateProgression() -> [ChordType] {
        let pool = chordPool
        guard pool.count >= progressionLength else {
            return Array(pool.prefix(progressionLength))
        }

        // Pick a common pattern if indices are valid for the pool, else random unique chords
        if let pattern = commonPatterns.randomElement(),
           pattern.allSatisfy({ $0 < pool.count }),
           pattern.count == progressionLength {
            return pattern.map { pool[$0] }
        }

        // Random unique selection
        var available = pool
        var result: [ChordType] = []
        for _ in 0..<progressionLength {
            guard let idx = available.indices.randomElement() else { break }
            result.append(available.remove(at: idx))
        }
        return result
    }

    // MARK: - Player Input

    /// Fills the active slot with the selected chord. Does not submit.
    func placeGuess(_ chord: ChordType) {
        guard gameState == .playing else { return }
        guard activeSlotIndex < playerGuesses.count else { return }

        playerGuesses[activeSlotIndex] = chord

        // Advance to next empty slot
        if activeSlotIndex < playerGuesses.count - 1 {
            activeSlotIndex += 1
        }
    }

    /// Lets the user tap a specific slot to go back and edit.
    func selectSlot(_ index: Int) {
        guard gameState == .playing, index >= 0, index < playerGuesses.count else { return }
        activeSlotIndex = index
    }

    /// Clears the current slot.
    func clearActiveSlot() {
        guard gameState == .playing else { return }
        guard activeSlotIndex < playerGuesses.count else { return }
        playerGuesses[activeSlotIndex] = nil
    }

    /// Evaluates the player's full progression guess.
    func submitProgression() {
        guard gameState == .playing else { return }
        guard playerGuesses.allSatisfy({ $0 != nil }) else { return }

        gameState = .evaluating

        let filledGuesses = playerGuesses.compactMap { $0 }

        // Record per-chord accuracy for each slot
        for (index, guess) in filledGuesses.enumerated() where index < currentProgression.count {
            let correct = currentProgression[index]
            if currentAttempt == 1 {
                userDataManager?.recordChordGuess(chord: correct, wasCorrect: guess == correct)
            }
        }

        let isFullyCorrect = filledGuesses == currentProgression

        if isFullyCorrect {
            let points = max(100 - (currentAttempt - 1) * 30, 20)
            score += points
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            totalCorrect += 1
            gameState = .answered

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.nextRound()
            }
        } else if currentAttempt < maxAttempts {
            // Give another attempt
            currentAttempt += 1
            gameState = .playing
        } else {
            currentStreak = 0
            gameState = .answered

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.nextRound()
            }
        }
    }

    func nextRound() {
        currentRound += 1
        startNewRound()
    }

    // MARK: - UI Helpers

    /// Which slots have the correct chord (only after .answered state).
    func isSlotCorrect(_ index: Int) -> Bool {
        guard index < playerGuesses.count, index < currentProgression.count else { return false }
        return playerGuesses[index] == currentProgression[index]
    }

    var allSlotsFilled: Bool {
        playerGuesses.allSatisfy { $0 != nil }
    }

    /// Chords available for selection (the full pool).
    var availableChords: [ChordType] { chordPool }
}
