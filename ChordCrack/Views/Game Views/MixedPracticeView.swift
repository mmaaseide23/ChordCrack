import SwiftUI

// MARK: - Mixed Practice View
struct MixedPracticeView: View {
    @StateObject private var mixedManager = MixedPracticeManager()
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    progressSection
                    difficultySection
                    guitarSection
                    hintsSection
                    audioSection
                    statusSection
                    
                    if mixedManager.gameState == .playing || mixedManager.gameState == .answered {
                        selectionSection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            mixedManager.startMixedPractice()
        }
        .onChange(of: mixedManager.currentAttempt) { _, _ in
            audioManager.resetForNewAttempt()
        }
        .onDisappear {
            if mixedManager.totalQuestions > 0 {
                GameStatsTracker.recordSession(
                    userDataManager: userDataManager,
                    gameType: GameTypeConstants.mixedPractice,
                    score: mixedManager.score,
                    streak: mixedManager.bestStreak,
                    correctAnswers: mixedManager.totalCorrect,
                    totalQuestions: mixedManager.totalQuestions
                )
            }
        }
    }
    
    private var headerSection: some View {
        GameHeaderView(
            gameType: .mixedPractice,
            currentRound: mixedManager.currentRound,
            totalRounds: mixedManager.totalRounds,
            score: mixedManager.score,
            streak: mixedManager.currentStreak,
            showPauseButton: false,
            onPause: nil,
            onEndGame: {
                presentationMode.wrappedValue.dismiss()
            }
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
        VStack(spacing: 16) {
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
            
            if let chord = mixedManager.currentChord {
                HStack(spacing: 8) {
                    Image(systemName: "guitars.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.purple)
                    
                    Text(chord.difficultyLevel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                    
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
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var hintsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...6, id: \.self) { attempt in
                    HintProgressDot(
                        attempt: attempt,
                        currentAttempt: mixedManager.currentAttempt,
                        hintType: getHintType(for: attempt)
                    )
                }
            }
            
            Text(mixedManager.hintDescription)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if mixedManager.currentAttempt == 6 && mixedManager.revealedFingerIndex >= 0 {
                fingerHint
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.secondaryBackground)
        )
    }
    
    private var fingerHint: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "hand.point.up.fill")
                    .foregroundColor(Color.yellow)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Finger Position Revealed!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("The yellow dot shows one correct finger placement")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.1))
        )
    }
    
    private var audioSection: some View {
        GameAudioControlSection(
            gameType: .mixedPractice,
            currentAttempt: mixedManager.currentAttempt,
            maxAttempts: mixedManager.maxAttempts,
            showAudioOptions: true,
            audioManager: audioManager,
            currentChord: mixedManager.currentChord,
            currentHintType: mixedManager.currentHintType,
            selectedAudioOption: mixedManager.selectedAudioOption,
            onPlayChord: playCurrentChord
        )
    }
    
    @ViewBuilder
    private var statusSection: some View {
        switch mixedManager.gameState {
        case .playing:
            VStack(spacing: 8) {
                Text("Listen & Identify")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("Identify this mystery chord from any category!")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .padding(.vertical, 12)
            
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
    
    private func getHintType(for attempt: Int) -> GameManager.HintType {
        switch attempt {
        case 1, 2: return .chordNoFingers
        case 3: return .chordSlow
        case 4: return .individualStrings
        case 5: return .audioOptions
        case 6: return .singleFingerReveal
        default: return .chordNoFingers
        }
    }
}

// MARK: - Supporting Views

struct MixedResultView: View {
    @EnvironmentObject var mixedManager: MixedPracticeManager
    @State private var showingAnimation = false
    
    var body: some View {
        let isCorrect = mixedManager.selectedChord == mixedManager.currentChord
        let categoryColor = mixedManager.currentCategory?.color ?? Color.purple
        
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCorrect ? categoryColor.opacity(0.2) : ColorTheme.error.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(showingAnimation ? 1.1 : 0.9)
                
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isCorrect ? categoryColor : ColorTheme.error)
            }
            
            VStack(spacing: 8) {
                Text(isCorrect ? "Perfect!" : "Not Quite!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isCorrect ? categoryColor : ColorTheme.error)
                
                if !isCorrect {
                    Text("Correct answer: \(mixedManager.currentChord?.displayName ?? "")")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
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
        VStack(spacing: 16) {
            if !mixedManager.attempts.isEmpty {
                previousAttemptsView
            }
            
            headerSection
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    chordCategorySection(.basic, ChordType.basicChords)
                    chordCategorySection(.power, ChordType.powerChords)
                    chordCategorySection(.barre, ChordType.barreChords)
                    chordCategorySection(.blues, ChordType.bluesChords)
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var previousAttemptsView: some View {
        VStack(spacing: 12) {
            Text("Previous Attempts:")
                .font(.system(size: 14))
                .foregroundColor(ColorTheme.textSecondary)
            
            HStack(spacing: 12) {
                ForEach(0..<mixedManager.maxAttempts, id: \.self) { index in
                    Circle()
                        .fill(attemptColor(for: index))
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Select from any chord type:")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Rectangle()
                .fill(Color.purple)
                .frame(width: 50, height: 2)
                .cornerRadius(1)
        }
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
