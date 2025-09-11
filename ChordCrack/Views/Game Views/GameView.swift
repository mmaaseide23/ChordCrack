import SwiftUI

/// Enhanced gamified game view with professional progression system
struct GameView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPauseMenu = false
    @State private var comboMultiplier = 1.0
    @State private var showingComboEffect = false
    
    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Consistent header section
                    GameHeaderView(
                        gameType: .dailyChallenge,
                        currentRound: gameManager.currentRound,
                        totalRounds: 5,
                        score: gameManager.score,
                        streak: gameManager.streak,
                        showPauseButton: true,
                        onPause: {
                            showingPauseMenu = true
                        },
                        onEndGame: nil
                    )
                    
                    // Consistent progress section
                    GameProgressSection(
                        gameType: .dailyChallenge,
                        currentRound: gameManager.currentRound,
                        totalRounds: 5,
                        currentAttempt: gameManager.currentAttempt,
                        maxAttempts: 6,
                        score: gameManager.score
                    )
                    
                    // Guitar neck section
                    guitarNeckSection
                    
                    // Hint system section
                    hintSystemSection
                    
                    // Audio control section
                    GameAudioControlSection(
                        gameType: .dailyChallenge,
                        currentAttempt: gameManager.currentAttempt,
                        maxAttempts: 6,
                        showAudioOptions: gameManager.showAudioOptions,
                        audioManager: audioManager,
                        currentChord: gameManager.currentChord,
                        currentHintType: gameManager.currentHintType,
                        selectedAudioOption: gameManager.selectedAudioOption,
                        onPlayChord: playCurrentChord,
                        onAudioOptionChange: { option in
                            gameManager.updateSelectedAudioOption(option)
                        }
                    )
                    
                    // Game status section
                    gameStatusSection
                    
                    // Chord selection section
                    if gameManager.gameState == .playing || gameManager.gameState == .answered {
                        chordSelectionSection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            
            // Combo effect overlay
            if showingComboEffect {
                comboEffectOverlay
            }
        }
        .navigationBarHidden(true)
        .onChange(of: gameManager.streak) { oldValue, newValue in
            if newValue > oldValue && newValue >= 3 {
                triggerComboEffect()
            }
        }
        .onChange(of: gameManager.currentAttempt) { oldValue, newValue in
            audioManager.resetForNewAttempt()
        }
        .sheet(isPresented: $showingPauseMenu) {
            PauseMenuView(presentationMode: presentationMode)
                .environmentObject(gameManager)
        }
        .onAppear {
            // Start the game when view appears
            if !gameManager.isGameActive {
                gameManager.startNewGame()
            }
            // Set user data manager
            gameManager.setUserDataManager(userDataManager)
        }
        // REMOVED .onDisappear - stats are now only recorded when game is completed
    }
    
    private var guitarNeckSection: some View {
        VStack(spacing: 16) {
            GuitarNeckView(
                chord: gameManager.currentChord,
                currentAttempt: gameManager.currentAttempt,
                jumbledPositions: gameManager.jumbledFingerPositions,
                revealedFingerIndex: gameManager.revealedFingerIndex
            )
            .onAppear {
                gameManager.setAudioManager(audioManager)
            }
            .onChange(of: audioManager.isPlaying) { oldValue, newValue in
                if newValue && !oldValue {
                    NotificationCenter.default.post(name: .triggerStringShake, object: nil)
                }
            }
            
            if let chord = gameManager.currentChord {
                HStack(spacing: 8) {
                    Image(systemName: "guitars.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.primaryGreen)
                    
                    Text(chord.difficultyLevel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Spacer()
                    
                    Text("Basic Chord")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ColorTheme.primaryGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ColorTheme.primaryGreen.opacity(0.15))
                        )
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var hintSystemSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...6, id: \.self) { attempt in
                    HintProgressDot(
                        attempt: attempt,
                        currentAttempt: gameManager.currentAttempt,
                        hintType: getHintType(for: attempt)
                    )
                }
            }
            
            Text(gameManager.hintDescription)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if gameManager.currentAttempt == 6 && gameManager.revealedFingerIndex >= 0 {
                fingerRevealHint
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorTheme.primaryGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var fingerRevealHint: some View {
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
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // Game Over View with working exit button
    @ViewBuilder
    private var gameStatusSection: some View {
        switch gameManager.gameState {
        case .playing:
            VStack(spacing: 8) {
                Text("Listen & Identify")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("What chord is being played?")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .padding(.vertical, 12)
            
        case .answered:
            EnhancedResultView()
                .environmentObject(gameManager)
            
        case .gameOver:
            EnhancedGameOverView(presentationMode: presentationMode)
                .environmentObject(gameManager)
                
        default:
            EmptyView()
        }
    }
    
    // Use ChordSelectionView instead of EnhancedChordSelectionView
    private var chordSelectionSection: some View {
        ChordSelectionView()
            .environmentObject(gameManager)
    }
    
    private var comboEffectOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("COMBO!")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Color.orange)
                    .scaleEffect(showingComboEffect ? 1.2 : 0.8)
                    .opacity(showingComboEffect ? 1 : 0)
                
                Text("\(gameManager.streak) Streak")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .scaleEffect(showingComboEffect ? 1.1 : 0.9)
                    .opacity(showingComboEffect ? 1 : 0)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingComboEffect)
    }
    
    private func playCurrentChord() {
        if let chord = gameManager.currentChord {
            audioManager.playChord(
                chord,
                hintType: gameManager.currentHintType,
                audioOption: gameManager.selectedAudioOption
            )
        }
    }
    
    private func triggerComboEffect() {
        showingComboEffect = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingComboEffect = false
        }
    }
    
    private func getHintType(for attempt: Int) -> GameManager.HintType {
        switch attempt {
        case 1, 2: return .chordNoFingers
        case 3, 4, 5, 6: return .audioOptions
        default: return .chordNoFingers
        }
    }
}

// MARK: - Supporting Views

struct HintProgressDot: View {
    let attempt: Int
    let currentAttempt: Int
    let hintType: GameManager.HintType
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(attempt == currentAttempt ? ColorTheme.primaryGreen : Color.clear, lineWidth: 2)
                        .frame(width: 16, height: 16)
                )
            
            Text(hintLabel)
                .font(.system(size: 8))
                .foregroundColor(ColorTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var dotColor: Color {
        if attempt < currentAttempt {
            return ColorTheme.primaryGreen
        } else if attempt == currentAttempt {
            return Color.orange
        } else {
            return ColorTheme.textTertiary.opacity(0.3)
        }
    }
    
    private var hintLabel: String {
        switch hintType {
        case .chordNoFingers: return "Full"
        case .chordSlow: return "Slow"
        case .individualStrings: return "Split"
        case .audioOptions: return "Choice"
        case .singleFingerReveal: return "Reveal"
        }
    }
}

struct EnhancedResultView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showingAnimation = false
    
    var body: some View {
        let isCorrect = gameManager.selectedChord == gameManager.currentChord
        
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCorrect ? ColorTheme.primaryGreen.opacity(0.2) : ColorTheme.error.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(showingAnimation ? 1.1 : 0.9)
                
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isCorrect ? ColorTheme.primaryGreen : ColorTheme.error)
                    .scaleEffect(showingAnimation ? 1.0 : 0.8)
            }
            
            VStack(spacing: 8) {
                Text(isCorrect ? "Perfect!" : "Not Quite!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isCorrect ? ColorTheme.primaryGreen : ColorTheme.error)
                
                if !isCorrect {
                    Text("The correct answer was \(gameManager.currentChord?.displayName ?? "")")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                
                if isCorrect {
                    let points = max(60 - (gameManager.currentAttempt - 1) * 10, 10)
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(Color.orange)
                        
                        Text("+\(points) points")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                }
                
                if gameManager.streak >= 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Color.orange)
                        
                        Text("Streak: \(gameManager.streak)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCorrect ? ColorTheme.primaryGreen.opacity(0.3) : ColorTheme.error.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showingAnimation = true
            }
        }
    }
}

// Game Over View with working exit button
struct EnhancedGameOverView: View {
    @EnvironmentObject var gameManager: GameManager
    let presentationMode: Binding<PresentationMode>
    @State private var showingCelebration = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(ColorTheme.primaryGreen.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(showingCelebration ? 1.2 : 1.0)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.yellow)
                    .rotationEffect(.degrees(showingCelebration ? 360 : 0))
            }
            
            VStack(spacing: 12) {
                Text("Challenge Complete!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        ScoreStatItem(label: "Final Score", value: "\(gameManager.score)", color: ColorTheme.primaryGreen)
                        ScoreStatItem(label: "Best Streak", value: "\(gameManager.bestStreak)", color: Color.orange)
                    }
                    
                    Text(getPerformanceMessage())
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 12) {
                Button("Play Again") {
                    gameManager.startNewGame()
                }
                .buttonStyle(PrimaryGameButtonStyle(color: ColorTheme.primaryGreen))
                
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
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(ColorTheme.primaryGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.3)) {
                showingCelebration = true
            }
        }
    }
    
    private func getPerformanceMessage() -> String {
        let accuracy = Double(gameManager.totalCorrect) / Double(gameManager.totalQuestions) * 100.0
        
        if accuracy >= 90 {
            return "Outstanding! You're a chord recognition master!"
        } else if accuracy >= 70 {
            return "Great job! Your ear training is really improving!"
        } else if accuracy >= 50 {
            return "Good progress! Keep practicing to improve your accuracy."
        } else {
            return "Keep practicing! Every attempt makes you better!"
        }
    }
}

// Pause Menu with working exit button
struct PauseMenuView: View {
    @EnvironmentObject var gameManager: GameManager
    let presentationMode: Binding<PresentationMode>
    @Environment(\.presentationMode) var modalPresentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Game Paused")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            VStack(spacing: 16) {
                Button("Resume Game") {
                    modalPresentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryGameButtonStyle(color: ColorTheme.primaryGreen))
                
                Button("Restart Challenge") {
                    gameManager.startNewGame()
                    modalPresentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(SecondaryGameButtonStyle())
                
                Button("Quit to Home") {
                    modalPresentationMode.wrappedValue.dismiss()
                    presentationMode.wrappedValue.dismiss()
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

struct ScoreStatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
        }
    }
}

#Preview {
    GameView()
        .environmentObject(GameManager())
        .environmentObject(AudioManager())
        .environmentObject(UserDataManager())
        .background(ColorTheme.background)
}
