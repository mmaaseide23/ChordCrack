import SwiftUI

// MARK: - Mixed Practice View
struct MixedPracticeView: View {
    @StateObject private var mixedManager = MixedPracticeManager()
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPauseMenu = false

    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    headerSection
                    progressSection
                    difficultySection
                    guitarSection
                    audioSection
                    statusSection

                    if mixedManager.gameState == .playing || mixedManager.gameState == .answered {
                        selectionSection
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            mixedManager.startMixedPractice()
        }
        .onChange(of: mixedManager.currentAttempt) { _, _ in
            audioManager.resetForNewAttempt()
        }
        .onChange(of: mixedManager.gameState) { oldValue, newValue in
            // Only record stats when game transitions to completed state
            if newValue == .completed && mixedManager.isGameCompleted {
                recordGameStats()
            }
        }
        .sheet(isPresented: $showingPauseMenu) {
            PracticePauseMenuView(
                gameType: .mixedPractice,
                onResume: { showingPauseMenu = false },
                onRestart: {
                    mixedManager.startMixedPractice()
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
        guard mixedManager.isGameCompleted && mixedManager.totalQuestions > 0 else {
            debugLog("[MixedPracticeView] Game not completed or no questions answered, skipping stats")
            return
        }
        
        debugLog("[MixedPracticeView] Recording completed mixed practice session")
        
        GameStatsTracker.recordSession(
            userDataManager: userDataManager,
            gameType: GameTypeConstants.mixedPractice,
            score: mixedManager.score,
            streak: mixedManager.bestStreak,
            correctAnswers: mixedManager.totalCorrect,
            totalQuestions: mixedManager.totalQuestions
        )
    }
    
    private var headerSection: some View {
        GameHeaderView(
            gameType: .mixedPractice,
            currentRound: mixedManager.currentRound,
            totalRounds: mixedManager.totalRounds,
            score: mixedManager.score,
            streak: mixedManager.currentStreak,
            showPauseButton: true,
            onPause: { showingPauseMenu = true },
            onEndGame: nil
        )
    }
    
    private var progressSection: some View {
        GameProgressSection(
            gameType: .mixedPractice,
            currentRound: mixedManager.currentRound,
            totalRounds: mixedManager.totalRounds,
            currentAttempt: mixedManager.currentAttempt,
            maxAttempts: mixedManager.maxAttempts,
            score: mixedManager.score
        )
    }
    
    private var difficultySection: some View {
        Group {
            if let currentCategory = mixedManager.currentCategory {
                HStack(spacing: 12) {
                    Circle()
                        .fill(currentCategory.color)
                        .frame(width: 12, height: 12)
                    
                    Text("Current: \(currentCategory.displayName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Spacer()
                    
                    Text(mixedManager.currentChord?.difficultyLevel ?? "")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(currentCategory.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(currentCategory.color.opacity(0.15))
                        )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.secondaryBackground)
                )
            }
        }
    }
    
    private var guitarSection: some View {
        VStack(spacing: 8) {
            GuitarNeckView(
                chord: mixedManager.currentChord,
                currentAttempt: mixedManager.currentAttempt,
                jumbledPositions: mixedManager.jumbledFingerPositions,
                revealedFingerIndex: mixedManager.revealedFingerIndex
            )
            .onChange(of: audioManager.isPlaying) { _, newValue in
                if newValue {
                    NotificationCenter.default.post(name: .triggerStringShake, object: nil)
                }
            }

            // Compact hint dots + category badge inline
            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { attempt in
                    Circle()
                        .fill(attempt < mixedManager.currentAttempt ? Color.purple :
                              attempt == mixedManager.currentAttempt ? Color.orange :
                              ColorTheme.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }

                Spacer()

                Text("Mixed Challenge")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.purple.opacity(0.15))
                    )
            }
            .padding(.horizontal, 4)

            // Finger reveal hint (attempt 6 only)
            if mixedManager.currentAttempt == 6 && mixedManager.revealedFingerIndex >= 0 {
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
            gameType: .mixedPractice,
            currentAttempt: mixedManager.currentAttempt,
            maxAttempts: mixedManager.maxAttempts,
            showAudioOptions: mixedManager.showAudioOptions,
            audioManager: audioManager,
            currentChord: mixedManager.currentChord,
            currentHintType: mixedManager.currentHintType,
            selectedAudioOption: mixedManager.selectedAudioOption,
            onPlayChord: playCurrentChord,
            onAudioOptionChange: { option in
                mixedManager.updateSelectedAudioOption(option)
            }
        )
    }
    
    @ViewBuilder
    private var statusSection: some View {
        switch mixedManager.gameState {
        case .playing:
            Text("Identify this mystery chord from any category!")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .padding(.vertical, 4)

        case .answered:
            MixedResultView()
                .environmentObject(mixedManager)

        case .completed:
            MixedCompletedView()
                .environmentObject(mixedManager)

        default:
            EmptyView()
        }
    }
    
    private var selectionSection: some View {
        MixedChordSelectionView()
            .environmentObject(mixedManager)
    }
    
    private func playCurrentChord() {
        guard let chord = mixedManager.currentChord else { return }
        audioManager.playChord(
            chord,
            hintType: mixedManager.currentHintType,
            audioOption: mixedManager.selectedAudioOption
        )
    }
    
}

// MARK: - Supporting Views

struct MixedResultView: View {
    @EnvironmentObject var mixedManager: MixedPracticeManager
    @State private var showingAnimation = false

    var body: some View {
        let isCorrect = mixedManager.selectedChord == mixedManager.currentChord
        let categoryColor = mixedManager.currentCategory?.color ?? Color.purple

        HStack(spacing: 12) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(isCorrect ? categoryColor : ColorTheme.error)
                .scaleEffect(showingAnimation ? 1.0 : 0.7)

            VStack(alignment: .leading, spacing: 4) {
                Text(isCorrect ? "Correct!" : "Not Quite!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isCorrect ? categoryColor : ColorTheme.error)

                if !isCorrect {
                    Text("Answer: \(mixedManager.currentChord?.displayName ?? "")")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCorrect ? categoryColor.opacity(0.1) : ColorTheme.error.opacity(0.1))
        )
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showingAnimation = true
            }
        }
    }
}

struct MixedCompletedView: View {
    @EnvironmentObject var mixedManager: MixedPracticeManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingCelebration = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 50))
                .foregroundColor(Color.yellow)
            
            Text("Mixed Practice Complete!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text("Final Score: \(mixedManager.score)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.purple)
            
            VStack(spacing: 12) {
                Button("Play Again") {
                    mixedManager.startMixedPractice()
                }
                .buttonStyle(PrimaryGameButtonStyle(color: Color.purple))
                
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

// MARK: - Mixed Chord Selection View (Styled)
struct MixedChordSelectionView: View {
    @EnvironmentObject var mixedManager: MixedPracticeManager

    var body: some View {
        VStack(spacing: 10) {
            // Compact header with inline attempts
            HStack {
                Text("Select from any chord:")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<mixedManager.maxAttempts, id: \.self) { index in
                        Circle()
                            .fill(attemptColor(for: index))
                            .frame(width: 10, height: 10)
                    }
                }
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    chordCategorySection(.basic, ChordType.basicChords)
                    chordCategorySection(.power, ChordType.powerChords)
                    chordCategorySection(.barre, ChordType.barreChords)
                    chordCategorySection(.blues, ChordType.bluesChords)
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func chordCategorySection(_ category: ChordCategory, _ chords: [ChordType]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(category.color)
                    .frame(width: 8, height: 8)
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(chords) { chord in
                    StyledChordButton(
                        chord: chord,
                        gameType: .mixedPractice,
                        isSelected: chord == mixedManager.selectedChord,
                        isCorrect: mixedManager.gameState == .answered && chord == mixedManager.currentChord,
                        isWrong: mixedManager.gameState == .answered && chord == mixedManager.selectedChord && chord != mixedManager.currentChord,
                        isDisabled: mixedManager.gameState != .playing,
                        isCompact: true
                    ) {
                        mixedManager.submitGuess(chord)
                    }
                }
            }
        }
    }
    
    private func attemptColor(for index: Int) -> Color {
        if index < mixedManager.attempts.count {
            if let attempt = mixedManager.attempts[index] {
                return attempt == mixedManager.currentChord ? Color.purple : ColorTheme.error
            }
        } else if index == mixedManager.currentAttempt - 1 {
            return Color.purple.opacity(0.5)
        }
        return ColorTheme.textTertiary.opacity(0.3)
    }
}
