import SwiftUI

// MARK: - Base Practice View
struct PracticeView: View {
    let category: ChordCategory
    @StateObject private var practiceManager = PracticeManager()
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPauseMenu = false

    var gameType: GameType {
        switch category {
        case .basic: return .basicPractice
        case .barre: return .barrePractice
        case .blues: return .bluesPractice
        case .power: return .powerPractice
        }
    }

    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    headerSection
                    progressSection
                    guitarSection
                    audioSection
                    statusSection

                    if practiceManager.gameState == .playing || practiceManager.gameState == .answered {
                        selectionSection
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            practiceManager.startPracticeSession(for: category)
        }
        .onChange(of: practiceManager.currentAttempt) { oldValue, newValue in
            audioManager.resetForNewAttempt()
        }
        .onChange(of: practiceManager.gameState) { oldValue, newValue in
            // Only record stats when game transitions to completed state
            if newValue == .completed && practiceManager.isGameCompleted {
                recordGameStats()
            }
        }
        .sheet(isPresented: $showingPauseMenu) {
            PracticePauseMenuView(
                gameType: gameType,
                onResume: { showingPauseMenu = false },
                onRestart: {
                    practiceManager.startPracticeSession(for: category)
                    showingPauseMenu = false
                },
                onQuit: {
                    showingPauseMenu = false
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func recordGameStats() {
        // Only record if game was actually completed with questions answered
        guard practiceManager.isGameCompleted && practiceManager.totalQuestions > 0 else {
            debugLog("[PracticeView] Game not completed or no questions answered, skipping stats")
            return
        }
        
        debugLog("[PracticeView] Recording completed \(category.rawValue) practice session")
        
        GameStatsTracker.recordSession(
            userDataManager: userDataManager,
            gameType: category.statKey,
            score: practiceManager.score,
            streak: practiceManager.bestStreak,
            correctAnswers: practiceManager.totalCorrect,
            totalQuestions: practiceManager.totalQuestions
        )
    }
    
    private var headerSection: some View {
        GameHeaderView(
            gameType: gameType,
            currentRound: practiceManager.currentRound,
            totalRounds: practiceManager.totalRounds,
            score: practiceManager.score,
            streak: practiceManager.currentStreak,
            showPauseButton: true,
            onPause: { showingPauseMenu = true },
            onEndGame: nil
        )
    }
    
    private var progressSection: some View {
        GameProgressSection(
            gameType: gameType,
            currentRound: practiceManager.currentRound,
            totalRounds: practiceManager.totalRounds,
            currentAttempt: practiceManager.currentAttempt,
            maxAttempts: practiceManager.maxAttempts,
            score: practiceManager.score
        )
    }
    
    private var guitarSection: some View {
        VStack(spacing: 8) {
            GuitarNeckView(
                chord: practiceManager.currentChord,
                currentAttempt: practiceManager.currentAttempt,
                jumbledPositions: practiceManager.jumbledFingerPositions,
                revealedFingerIndex: practiceManager.revealedFingerIndex
            )
            .onChange(of: audioManager.isPlaying) { oldValue, newValue in
                if newValue && !oldValue {
                    NotificationCenter.default.post(name: .triggerStringShake, object: nil)
                }
            }

            // Compact hint dots + category badge inline
            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { attempt in
                    Circle()
                        .fill(attempt < practiceManager.currentAttempt ? gameType.color :
                              attempt == practiceManager.currentAttempt ? Color.orange :
                              ColorTheme.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }

                Spacer()

                if practiceManager.currentChord != nil {
                    Text(category.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(gameType.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(gameType.color.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 4)

            // Finger reveal hint (attempt 6 only)
            if practiceManager.currentAttempt == 6 && practiceManager.revealedFingerIndex >= 0 {
                HStack(spacing: 8) {
                    Image(systemName: "hand.point.up.fill")
                        .foregroundColor(Color.yellow)
                        .font(.system(size: 14))

                    Text("Yellow dot = correct finger position")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)

                    Spacer()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                )
            }
        }
    }
    
    private var audioSection: some View {
        GameAudioControlSection(
            gameType: gameType,
            currentAttempt: practiceManager.currentAttempt,
            maxAttempts: practiceManager.maxAttempts,
            showAudioOptions: practiceManager.showAudioOptions,
            audioManager: audioManager,
            currentChord: practiceManager.currentChord,
            currentHintType: practiceManager.currentHintType,
            selectedAudioOption: practiceManager.selectedAudioOption,
            onPlayChord: playCurrentChord,
            onAudioOptionChange: { option in
                practiceManager.updateSelectedAudioOption(option)
            }
        )
    }
    
    @ViewBuilder
    private var statusSection: some View {
        switch practiceManager.gameState {
        case .playing:
            Text("What \(category.rawValue.lowercased()) chord is being played?")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .padding(.vertical, 4)

        case .answered:
            PracticeResultView(category: category, gameType: gameType)
                .environmentObject(practiceManager)

        case .completed:
            PracticeCompletedView(category: category, gameType: gameType)
                .environmentObject(practiceManager)

        default:
            EmptyView()
        }
    }
    
    private var selectionSection: some View {
        PracticeChordSelectionView(category: category, gameType: gameType)
            .environmentObject(practiceManager)
    }
    
    private func playCurrentChord() {
        guard let chord = practiceManager.currentChord else { return }
        audioManager.playChord(
            chord,
            hintType: practiceManager.currentHintType,
            audioOption: practiceManager.selectedAudioOption
        )
    }
    
}

// MARK: - Practice Result View (Compact)
struct PracticeResultView: View {
    let category: ChordCategory
    let gameType: GameType
    @EnvironmentObject var practiceManager: PracticeManager
    @State private var showingAnimation = false

    var body: some View {
        let isCorrect = practiceManager.selectedChord == practiceManager.currentChord

        HStack(spacing: 12) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(isCorrect ? gameType.color : ColorTheme.error)
                .scaleEffect(showingAnimation ? 1.0 : 0.7)

            VStack(alignment: .leading, spacing: 4) {
                Text(isCorrect ? "Correct!" : "Not Quite!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isCorrect ? gameType.color : ColorTheme.error)

                if !isCorrect {
                    Text("Answer: \(practiceManager.currentChord?.displayName ?? "")")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCorrect ? gameType.color.opacity(0.1) : ColorTheme.error.opacity(0.1))
        )
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showingAnimation = true
            }
        }
    }
}

// MARK: - Practice Completed View
struct PracticeCompletedView: View {
    let category: ChordCategory
    let gameType: GameType
    @EnvironmentObject var practiceManager: PracticeManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingCelebration = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 50))
                .foregroundColor(Color.yellow)
            
            Text("Practice Complete!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text("Final Score: \(practiceManager.score)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(gameType.color)
            
            VStack(spacing: 12) {
                Button("Play Again") {
                    practiceManager.startPracticeSession(for: category)
                }
                .buttonStyle(PrimaryGameButtonStyle(color: gameType.color))
                
                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(SecondaryGameButtonStyle())
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorTheme.cardBackground)
        )
    }
}

// MARK: - Practice Chord Selection View (Styled)
struct PracticeChordSelectionView: View {
    let category: ChordCategory
    let gameType: GameType
    @EnvironmentObject var practiceManager: PracticeManager
    
    var availableChords: [ChordType] {
        switch category {
        case .basic: return ChordType.basicChords
        case .barre: return ChordType.barreChords
        case .blues: return ChordType.bluesChords
        case .power: return ChordType.powerChords
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Compact header with inline attempts
            HStack {
                Text("Select the \(category.rawValue.lowercased()) chord:")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<practiceManager.maxAttempts, id: \.self) { index in
                        Circle()
                            .fill(attemptColor(for: index))
                            .frame(width: 10, height: 10)
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(availableChords) { chord in
                    StyledChordButton(
                        chord: chord,
                        gameType: gameType,
                        isSelected: chord == practiceManager.selectedChord,
                        isCorrect: practiceManager.gameState == .answered && chord == practiceManager.currentChord,
                        isWrong: practiceManager.gameState == .answered && chord == practiceManager.selectedChord && chord != practiceManager.currentChord,
                        isDisabled: practiceManager.gameState != .playing,
                        isCompact: true
                    ) {
                        practiceManager.submitGuess(chord)
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
    
    private func attemptColor(for index: Int) -> Color {
        if index < practiceManager.attempts.count {
            if let attempt = practiceManager.attempts[index] {
                return attempt == practiceManager.currentChord ? gameType.color : ColorTheme.error
            }
        } else if index == practiceManager.currentAttempt - 1 {
            return gameType.color.opacity(0.5)
        }
        return ColorTheme.textTertiary.opacity(0.3)
    }
}

// MARK: - Specific Practice Views
struct BarreChordsPracticeView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        PracticeView(category: .barre)
            .environmentObject(audioManager)
    }
}

struct BluesChordsPracticeView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        PracticeView(category: .blues)
            .environmentObject(audioManager)
    }
}

struct PowerChordsPracticeView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        PracticeView(category: .power)
            .environmentObject(audioManager)
    }
}

// MARK: - Practice Pause Menu
struct PracticePauseMenuView: View {
    let gameType: GameType
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Paused")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)

            VStack(spacing: 12) {
                Button("Resume") {
                    onResume()
                }
                .buttonStyle(PrimaryGameButtonStyle(color: gameType.color))

                Button("Restart Practice") {
                    onRestart()
                }
                .buttonStyle(SecondaryGameButtonStyle())

                Button("Quit to Home") {
                    onQuit()
                }
                .buttonStyle(SecondaryGameButtonStyle())
            }
        }
        .padding(24)
        .background(ColorTheme.cardBackground)
        .cornerRadius(20)
        .padding(40)
    }
}
