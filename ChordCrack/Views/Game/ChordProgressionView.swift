import SwiftUI

/// Chord Progressions mode — listen to a sequence of 4 chords and identify each in order.
struct ChordProgressionView: View {
    @StateObject private var manager = ChordProgressionManager()
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode

    @State private var showingPauseMenu = false
    @State private var hasPlayedOnce = false

    private let gameType: GameType = .chordProgression

    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection
                    progressSection
                    instructionSection
                    playButtonSection
                    progressionSlotsSection
                    statusSection

                    if manager.gameState == .playing {
                        chordSelectionSection
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
        .onDisappear { audioManager.resetForNewRound() }
        .onAppear {
            manager.setUserDataManager(userDataManager)
            audioManager.resetForNewRound()
            manager.startSession()
        }
        .onChange(of: manager.currentRound) { _, _ in
            audioManager.resetForNewRound()
            hasPlayedOnce = false
        }
        .onChange(of: audioManager.isPlaying) { _, playing in
            if playing { hasPlayedOnce = true }
        }
        .onChange(of: manager.gameState) { _, newValue in
            switch newValue {
            case .answered:
                let isCorrect = manager.playerGuesses.compactMap { $0 } == manager.currentProgression
                if isCorrect {
                    HapticManager.shared.correctAnswer()
                } else {
                    HapticManager.shared.incorrectAnswer()
                }
            case .completed:
                if manager.isGameCompleted {
                    HapticManager.shared.celebration()
                    recordGameStats()
                }
            default:
                break
            }
        }
        .sheet(isPresented: $showingPauseMenu) {
            PracticePauseMenuView(
                gameType: gameType,
                onResume: { showingPauseMenu = false },
                onRestart: {
                    audioManager.resetForNewRound()
                    manager.startSession()
                    showingPauseMenu = false
                    hasPlayedOnce = false
                },
                onQuit: {
                    showingPauseMenu = false
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        GameHeaderView(
            gameType: gameType,
            currentRound: manager.currentRound,
            totalRounds: manager.totalRounds,
            score: manager.score,
            streak: manager.currentStreak,
            showPauseButton: true,
            onPause: { showingPauseMenu = true },
            onEndGame: nil
        )
    }

    private var progressSection: some View {
        GameProgressSection(
            gameType: gameType,
            currentRound: manager.currentRound,
            totalRounds: manager.totalRounds,
            currentAttempt: manager.currentAttempt,
            maxAttempts: manager.maxAttempts,
            score: manager.score,
            availablePoints: manager.gameState == .playing ? manager.availablePoints : nil
        )
    }

    private var instructionSection: some View {
        VStack(spacing: 6) {
            Text("Listen to the progression, then identify each chord in order.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)

            Text("Attempt \(manager.currentAttempt) of \(manager.maxAttempts)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(gameType.color)
        }
        .padding(.top, 4)
    }

    private var playButtonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                HapticManager.shared.buttonTap()
                playProgression()
            } label: {
                HStack(spacing: 16) {
                    if audioManager.isLoading {
                        ProgressView().tint(ColorTheme.background)
                    } else {
                        Image(systemName: audioManager.isPlaying ? "waveform" : "play.fill")
                            .font(.title2.weight(.semibold))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(audioManager.isLoading ? "Loading progression" : audioManager.isPlaying ? "Listen to the progression" : audioManager.errorMessage != nil ? "Try audio again" : hasPlayedOnce ? "Play again" : "Play progression")
                            .font(.headline)
                        Text("Four chords. Replay whenever you need.")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(ColorTheme.background)
                .padding(20).frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                .background(gameType.color, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(StudioPressStyle())
            .disabled(audioManager.isPlaying || audioManager.isLoading || manager.gameState != .playing)
            .accessibilityIdentifier("progression.listen")
            if audioManager.errorMessage != nil {
                Label("Couldn't play the full progression. Try again when you're connected.", systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(ColorTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var progressionSlotsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Your progression:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.textSecondary)

                Spacer()

                if manager.gameState == .playing && guessAt(manager.activeSlotIndex) != nil {
                    Button {
                        HapticManager.shared.buttonTap()
                        manager.clearActiveSlot()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 11))
                            Text("Clear slot")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(ColorTheme.error)
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<manager.currentProgression.count, id: \.self) { index in
                    slotView(for: index)
                }
            }

            if manager.gameState == .playing && manager.allSlotsFilled {
                Button {
                    HapticManager.shared.mediumImpact()
                    manager.submitProgression()
                } label: {
                    Text("Submit Progression")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ColorTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(gameType.color)
                        )
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(gameType.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func slotView(for index: Int) -> some View {
        let guess = guessAt(index)
        let isActive = index == manager.activeSlotIndex && manager.gameState == .playing
        let isAnswered = manager.gameState == .answered
        let isCorrect = isAnswered && manager.isSlotCorrect(index)
        let isWrong = isAnswered && !manager.isSlotCorrect(index)

        let borderColor: Color = {
            if isCorrect { return gameType.color }
            if isWrong { return ColorTheme.error }
            if isActive { return gameType.color }
            return ColorTheme.textTertiary.opacity(0.4)
        }()

        let fillColor: Color = {
            if isCorrect { return gameType.color.opacity(0.15) }
            if isWrong { return ColorTheme.error.opacity(0.15) }
            if isActive { return gameType.color.opacity(0.08) }
            return ColorTheme.secondaryBackground.opacity(0.4)
        }()

        Button {
            guard manager.gameState == .playing else { return }
            HapticManager.shared.selectionChanged()
            manager.selectSlot(index)
        } label: {
            VStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ColorTheme.textTertiary)

                Text(guess?.displayName ?? "—")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(guess != nil ? ColorTheme.textPrimary : ColorTheme.textTertiary)

                if isAnswered {
                    Text(manager.currentProgression[index].displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isCorrect ? gameType.color : ColorTheme.error)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isAnswered ? 72 : 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(borderColor, lineWidth: isActive ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(manager.gameState != .playing)
    }

    @ViewBuilder
    private var statusSection: some View {
        switch manager.gameState {
        case .answered:
            let isCorrect = manager.playerGuesses.compactMap { $0 } == manager.currentProgression
            HStack(spacing: 12) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isCorrect ? gameType.color : ColorTheme.error)
                Text(isCorrect ? "All correct!" : "Correct progression shown above.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCorrect ? gameType.color : ColorTheme.error)
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill((isCorrect ? gameType.color : ColorTheme.error).opacity(0.1))
            )

        case .completed:
            ProgressionCompletedView(manager: manager, gameType: gameType)

        default:
            EmptyView()
        }
    }

    private var chordSelectionSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Fill slot \(manager.activeSlotIndex + 1):")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(manager.availableChords) { chord in
                    StyledChordButton(
                        chord: chord,
                        gameType: gameType,
                        isSelected: guessAt(manager.activeSlotIndex) == chord,
                        isCorrect: false,
                        isWrong: false,
                        isDisabled: false,
                        isCompact: true
                    ) {
                        HapticManager.shared.buttonTap()
                        manager.placeGuess(chord)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(gameType.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers

    /// Safely returns the player's guess at a slot index, or nil if out of bounds.
    private func guessAt(_ index: Int) -> ChordType? {
        guard index >= 0, index < manager.playerGuesses.count else { return nil }
        return manager.playerGuesses[index]
    }

    // MARK: - Actions

    private func playProgression() {
        guard !manager.currentProgression.isEmpty else { return }
        audioManager.playChordSequence(manager.currentProgression, delayBetween: 1.4)
    }

    private func recordGameStats() {
        guard manager.isGameCompleted && manager.totalQuestions > 0 else { return }

        GameStatsTracker.recordSession(
            userDataManager: userDataManager,
            gameType: GameTypeConstants.chordProgressions,
            score: manager.score,
            streak: manager.bestStreak,
            correctAnswers: manager.totalCorrect,
            totalQuestions: manager.totalQuestions
        )
    }
}

// MARK: - Completed View

private struct ProgressionCompletedView: View {
    @ObservedObject var manager: ChordProgressionManager
    let gameType: GameType
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.yellow)

            Text("Progressions Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)

            Text("Final Score: \(manager.score)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(gameType.color)

            VStack(spacing: 10) {
                Button("Play Again") {
                    manager.startSession()
                }
                .buttonStyle(PrimaryGameButtonStyle(color: gameType.color))

                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(SecondaryGameButtonStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
        )
    }
}
