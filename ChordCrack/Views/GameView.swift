import SwiftUI

/// Enhanced gamified game view with professional progression system
struct GameView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode // FIXED: Added for navigation
    @State private var showingPauseMenu = false
    @State private var comboMultiplier = 1.0
    @State private var showingComboEffect = false
    
    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    gameHeaderSection
                    progressAndStatsSection
                    guitarNeckSection
                    hintSystemSection
                    audioControlSection
                    gameStatusSection
                    
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
            PauseMenuView(presentationMode: presentationMode) // FIXED: Pass presentation mode
                .environmentObject(gameManager)
        }
    }
    
    // MARK: - Game Header with Enhanced UI (FIXED - Shows 5 rounds correctly)
    
    private var gameHeaderSection: some View {
        HStack {
            // FIXED: Back button
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorTheme.primaryGreen)
                    
                    Text("Home")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorTheme.primaryGreen)
                }
            }
            
            Spacer()
            
            // Round progress with animated ring - FIXED to show 5 rounds
            ZStack {
                Circle()
                    .stroke(ColorTheme.secondaryBackground, lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: CGFloat(gameManager.currentRound - 1) / CGFloat(5)) // FIXED: Divide by 5
                    .stroke(ColorTheme.primaryGreen, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: gameManager.currentRound)
                
                VStack(spacing: 2) {
                    Text("\(gameManager.currentRound)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("of 5") // FIXED: Show "of 5" instead of "of 10"
                        .font(.system(size: 8))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Score with animated counter
            VStack(alignment: .center, spacing: 4) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ColorTheme.textSecondary)
                    .tracking(1)
                
                Text("\(gameManager.score)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(ColorTheme.primaryGreen)
            }
            
            Spacer()
            
            // Streak with flame effect
            HStack(spacing: 8) {
                if gameManager.streak >= 3 {
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.orange)
                        
                        if gameManager.streak >= 5 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.red)
                                .offset(y: -8)
                        }
                    }
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(gameManager.streak)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(gameManager.streak >= 3 ? Color.orange : ColorTheme.textPrimary)
                    
                    Text("STREAK")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .tracking(0.5)
                }
            }
            
            // Pause button
            Button(action: { showingPauseMenu = true }) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ColorTheme.textSecondary)
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - Progress and Stats Section (FIXED - Shows 5 rounds correctly)
    
    private var progressAndStatsSection: some View {
        VStack(spacing: 16) {
            progressBarSection
            gameStatsRow
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorTheme.primaryGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var progressBarSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Daily Challenge Progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Text("\(gameManager.currentRound - 1)/5 Complete") // FIXED: Show "/5" instead of "/10"
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ColorTheme.secondaryBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [ColorTheme.primaryGreen, ColorTheme.lightGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(
                            width: geometry.size.width * CGFloat(gameManager.currentRound - 1) / 5, // FIXED: Divide by 5
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.5), value: gameManager.currentRound)
                }
            }
            .frame(height: 8)
        }
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
            EnhancedGameOverView(presentationMode: presentationMode) // FIXED: Pass presentation mode
                .environmentObject(gameManager)
                
        default:
            EmptyView()
        }
    }
    
    // ... (other sections remain the same)
    
    private var gameStatsRow: some View {
        HStack(spacing: 20) {
            statPillOne
            statPillTwo
            statPillThree
        }
    }
    
    private var statPillOne: some View {
        let currentRound = Double(max(gameManager.currentRound - 1, 1))
        let scoreRatio = Double(gameManager.score) / (currentRound * 60.0)
        let accuracy = Int(scoreRatio * 100)
        
        return GameStatPill(
            icon: "target",
            value: "\(accuracy)%",
            label: "Accuracy",
            color: ColorTheme.primaryGreen
        )
    }
    
    private var statPillTwo: some View {
        GameStatPill(
            icon: "timer",
            value: "Attempt \(gameManager.currentAttempt)",
            label: "of \(gameManager.maxAttempts)",
            color: Color.blue
        )
    }
    
    private var statPillThree: some View {
        let points = max(60 - (gameManager.currentAttempt - 1) * 10, 10)
        return GameStatPill(
            icon: "star.fill",
            value: "\(points)",
            label: "Points",
            color: Color.orange
        )
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
    
    private var audioControlSection: some View {
        VStack(spacing: 16) {
            if gameManager.currentAttempt == 5 {
                SimpleAudioOptionsSelector()
                    .environmentObject(gameManager)
            }
            
            Button(action: playCurrentChord) {
                HStack(spacing: 12) {
                    ZStack {
                        if audioManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text(playButtonTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(buttonGradient)
                )
            }
            .disabled(audioManager.isLoading || gameManager.gameState != .playing || audioManager.hasPlayedThisAttempt)
            .scaleEffect(audioManager.isLoading || audioManager.hasPlayedThisAttempt ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: audioManager.isLoading)
            
            if let error = audioManager.errorMessage {
                errorDisplay(error)
            }
        }
    }
    
    private var chordSelectionSection: some View {
        EnhancedChordSelectionView()
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
    
    private var playButtonTitle: String {
        if audioManager.isLoading {
            return "Loading Audio..."
        } else if audioManager.isPlaying {
            return "Playing Chord..."
        } else if audioManager.hasPlayedThisAttempt {
            return "Audio Played"
        } else if gameManager.currentAttempt == 5 {
            return "Play \(gameManager.selectedAudioOption.rawValue)"
        } else {
            return "Play Mystery Chord"
        }
    }
    
    private var buttonGradient: LinearGradient {
        if audioManager.isLoading || audioManager.hasPlayedThisAttempt {
            return LinearGradient(
                colors: [ColorTheme.textTertiary, ColorTheme.textTertiary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [ColorTheme.primaryGreen, ColorTheme.lightGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func playCurrentChord() {
        guard let chord = gameManager.currentChord else { return }
        audioManager.playChord(chord, hintType: gameManager.currentHintType, audioOption: gameManager.selectedAudioOption)
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
        case 3: return .chordSlow
        case 4: return .individualStrings
        case 5: return .audioOptions
        case 6: return .singleFingerReveal
        default: return .chordNoFingers
        }
    }
    
    private func errorDisplay(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ColorTheme.error)
                .font(.caption)
            
            Text(error)
                .foregroundColor(ColorTheme.error)
                .font(.caption)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.error.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTheme.error.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Supporting Views (Unchanged from your original)

struct GameStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(ColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

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

// FIXED: Game Over View with working exit button
struct EnhancedGameOverView: View {
    @EnvironmentObject var gameManager: GameManager
    let presentationMode: Binding<PresentationMode> // FIXED: Accept presentation mode
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
                        ScoreStatItem(label: "Best Streak", value: "\(gameManager.streak)", color: Color.orange)
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
                .buttonStyle(PrimaryGameButtonStyle())
                
                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss() // FIXED: Working exit button
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
        let accuracy = Double(gameManager.score) / 300.0 // FIXED: Max possible score for 5 rounds (5 * 60 = 300)
        
        if accuracy >= 0.9 {
            return "Outstanding! You're a chord recognition master!"
        } else if accuracy >= 0.7 {
            return "Great job! Your ear training is really improving!"
        } else if accuracy >= 0.5 {
            return "Good progress! Keep practicing to improve your accuracy."
        } else {
            return "Keep practicing! Every attempt makes you better!"
        }
    }
}

// FIXED: Pause Menu with working exit button
struct PauseMenuView: View {
    @EnvironmentObject var gameManager: GameManager
    let presentationMode: Binding<PresentationMode> // FIXED: Accept presentation mode
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
                .buttonStyle(PrimaryGameButtonStyle())
                
                Button("Restart Challenge") {
                    gameManager.startNewGame()
                    modalPresentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(SecondaryGameButtonStyle())
                
                Button("Quit to Home") {
                    modalPresentationMode.wrappedValue.dismiss()
                    presentationMode.wrappedValue.dismiss() // FIXED: Working exit to home
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

// ... (rest of the supporting views remain the same)

struct EnhancedChordSelectionView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedChord: ChordType?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            if !gameManager.attempts.isEmpty {
                previousAttemptsView
            }
            
            VStack(spacing: 12) {
                Text("Select the chord:")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Rectangle()
                    .fill(ColorTheme.primaryGreen)
                    .frame(width: 60, height: 3)
                    .cornerRadius(1.5)
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ChordType.basicChords) { chord in
                    EnhancedChordButton(chord: chord)
                        .environmentObject(gameManager)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorTheme.primaryGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var previousAttemptsView: some View {
        VStack(spacing: 12) {
            Text("Previous Attempts:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
            
            HStack(spacing: 12) {
                ForEach(0..<gameManager.maxAttempts, id: \.self) { index in
                    Circle()
                        .fill(attemptColor(for: index))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: index < gameManager.attempts.count ? 1 : 0)
                        )
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private func attemptColor(for index: Int) -> Color {
        if index < gameManager.attempts.count {
            if let attempt = gameManager.attempts[index] {
                return attempt == gameManager.currentChord ? ColorTheme.primaryGreen : ColorTheme.error
            }
        } else if index == gameManager.currentAttempt - 1 {
            return Color.orange
        }
        return ColorTheme.textTertiary.opacity(0.3)
    }
}

struct EnhancedChordButton: View {
    let chord: ChordType
    @EnvironmentObject var gameManager: GameManager
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { selectChord() }) {
            Text(chord.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textColor)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(buttonBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
        }
        .disabled(gameManager.gameState != .playing)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0) {
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(buttonColor)
    }
    
    private var buttonColor: Color {
        if gameManager.gameState == .answered {
            if chord == gameManager.currentChord {
                return ColorTheme.primaryGreen
            } else if chord == gameManager.selectedChord {
                return ColorTheme.error
            }
        } else if chord == gameManager.selectedChord {
            return ColorTheme.primaryGreen.opacity(0.7)
        }
        return ColorTheme.secondaryBackground
    }
    
    private var textColor: Color {
        if gameManager.gameState == .answered {
            return .white
        } else if chord == gameManager.selectedChord {
            return .white
        }
        return ColorTheme.textPrimary
    }
    
    private var strokeColor: Color {
        if gameManager.gameState == .answered && chord == gameManager.currentChord {
            return ColorTheme.lightGreen
        } else if chord == gameManager.selectedChord {
            return ColorTheme.primaryGreen
        }
        return ColorTheme.textTertiary.opacity(0.2)
    }
    
    private var strokeWidth: CGFloat {
        if gameManager.gameState == .answered && chord == gameManager.currentChord {
            return 2
        } else if chord == gameManager.selectedChord {
            return 2
        }
        return 1
    }
    
    private func selectChord() {
        guard gameManager.gameState == .playing else { return }
        gameManager.submitGuess(chord)
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

struct SimpleAudioOptionsSelector: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Choose what to hear:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ColorTheme.textSecondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(GameManager.AudioOption.allCases, id: \.self) { option in
                    Button(action: {
                        gameManager.selectedAudioOption = option
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: iconForOption(option))
                                .font(.caption)
                                .foregroundColor(gameManager.selectedAudioOption == option ? .white : ColorTheme.textSecondary)
                            
                            Text(option.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(gameManager.selectedAudioOption == option ? .white : ColorTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(gameManager.selectedAudioOption == option ? ColorTheme.primaryGreen : ColorTheme.surfaceSecondary)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorTheme.primaryGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func iconForOption(_ option: GameManager.AudioOption) -> String {
        switch option {
        case .chord:
            return "music.note.list"
        case .arpeggiated:
            return "waveform"
        case .individual:
            return "dot.radiowaves.left.and.right"
        case .bass:
            return "speaker.wave.1"
        case .treble:
            return "speaker.wave.3"
        }
    }
}

struct PrimaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [ColorTheme.primaryGreen, ColorTheme.lightGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(ColorTheme.primaryGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.primaryGreen, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    GameView()
        .environmentObject(GameManager())
        .environmentObject(AudioManager())
        .background(ColorTheme.background)
}
