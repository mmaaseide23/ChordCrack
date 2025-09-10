import SwiftUI

// MARK: - Unified Game Header Component
struct GameHeaderView: View {
    let gameType: GameType
    let currentRound: Int
    let totalRounds: Int
    let score: Int
    let streak: Int
    let showPauseButton: Bool
    let onPause: (() -> Void)?
    let onEndGame: (() -> Void)?
    
    var body: some View {
        HStack {
            // Round progress with animated ring
            ZStack {
                Circle()
                    .stroke(ColorTheme.secondaryBackground, lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: CGFloat(currentRound - 1) / CGFloat(totalRounds))
                    .stroke(gameType.color, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: currentRound)
                
                VStack(spacing: 2) {
                    Text("\(currentRound)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("of \(totalRounds)")
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
                
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(gameType.color)
            }
            
            Spacer()
            
            // Streak with flame effect
            HStack(spacing: 8) {
                if streak >= 3 {
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.orange)
                        
                        if streak >= 5 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.red)
                                .offset(y: -8)
                        }
                    }
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(streak >= 3 ? Color.orange : ColorTheme.textPrimary)
                    
                    Text("STREAK")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .tracking(0.5)
                }
            }
            
            // Action button (Pause for Daily Challenge, End for Practice)
            if showPauseButton {
                Button(action: { onPause?() }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            } else {
                Button(action: { onEndGame?() }) {
                    Text("End")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Unified Progress Section
struct GameProgressSection: View {
    let gameType: GameType
    let currentRound: Int
    let totalRounds: Int
    let currentAttempt: Int
    let maxAttempts: Int
    let score: Int
    
    var body: some View {
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
                        .stroke(gameType.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var progressBarSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(gameType.displayName) Progress")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Text("\(currentRound - 1)/\(totalRounds) Complete")
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
                            colors: [gameType.color, gameType.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(
                            width: geometry.size.width * CGFloat(currentRound - 1) / CGFloat(totalRounds),
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.5), value: currentRound)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var gameStatsRow: some View {
        HStack(spacing: 20) {
            accuracyPill
            attemptPill
            pointsPill
        }
    }
    
    private var accuracyPill: some View {
        let currentRoundForCalc = Double(max(currentRound - 1, 1))
        let maxPossibleScore = currentRoundForCalc * 60.0
        let accuracy = maxPossibleScore > 0 ? Int((Double(score) / maxPossibleScore) * 100) : 0
        
        return GameStatPill(
            icon: "target",
            value: "\(accuracy)%",
            label: "Accuracy",
            color: gameType.color
        )
    }
    
    private var attemptPill: some View {
        return GameStatPill(
            icon: "timer",
            value: "Attempt \(min(currentAttempt, maxAttempts))",
            label: "of \(maxAttempts)",
            color: Color.blue
        )
    }
    
    private var pointsPill: some View {
        let points = max(60 - (currentAttempt - 1) * 10, 10)
        return GameStatPill(
            icon: "star.fill",
            value: "\(points)",
            label: "Points",
            color: Color.orange
        )
    }
}

// MARK: - GameStatPill Component
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

// MARK: - Unified Audio Control Section
struct GameAudioControlSection: View {
    let gameType: GameType
    let currentAttempt: Int
    let maxAttempts: Int
    let showAudioOptions: Bool
    let audioManager: AudioManager
    let currentChord: ChordType?
    let currentHintType: GameManager.HintType
    let selectedAudioOption: GameManager.AudioOption
    let onPlayChord: () -> Void
    let onAudioOptionChange: ((GameManager.AudioOption) -> Void)?
    
    init(gameType: GameType,
         currentAttempt: Int,
         maxAttempts: Int,
         showAudioOptions: Bool,
         audioManager: AudioManager,
         currentChord: ChordType?,
         currentHintType: GameManager.HintType,
         selectedAudioOption: GameManager.AudioOption,
         onPlayChord: @escaping () -> Void,
         onAudioOptionChange: ((GameManager.AudioOption) -> Void)? = nil) {
        self.gameType = gameType
        self.currentAttempt = currentAttempt
        self.maxAttempts = maxAttempts
        self.showAudioOptions = showAudioOptions
        self.audioManager = audioManager
        self.currentChord = currentChord
        self.currentHintType = currentHintType
        self.selectedAudioOption = selectedAudioOption
        self.onPlayChord = onPlayChord
        self.onAudioOptionChange = onAudioOptionChange
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Audio options selector for attempts 3-6
            if showAudioOptions && currentAttempt >= 3 {
                AudioOptionsSelector(
                    gameType: gameType,
                    selectedAudioOption: selectedAudioOption,
                    onOptionChange: onAudioOptionChange
                )
            }
            
            // Attempt indicator
            Text("Attempt \(currentAttempt) of \(maxAttempts)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(gameType.color)
            
            // Play button
            Button(action: onPlayChord) {
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
            .disabled(audioManager.isLoading || audioManager.hasPlayedThisAttempt)
            .scaleEffect(audioManager.isLoading || audioManager.hasPlayedThisAttempt ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: audioManager.isLoading)
            
            // Error display
            if let error = audioManager.errorMessage {
                errorDisplay(error)
            }
        }
    }
    
    private var playButtonTitle: String {
        if audioManager.isLoading {
            return "Loading Audio..."
        } else if audioManager.isPlaying {
            return "Playing Chord..."
        } else if audioManager.hasPlayedThisAttempt {
            return "Audio Played"
        } else if currentAttempt >= 3 && showAudioOptions {
            return "Play \(selectedAudioOption.rawValue)"
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
                colors: [gameType.color, gameType.color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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

// MARK: - Audio Options Selector
struct AudioOptionsSelector: View {
    let gameType: GameType
    let selectedAudioOption: GameManager.AudioOption
    let onOptionChange: ((GameManager.AudioOption) -> Void)?
    
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
                    AudioOptionButton(
                        option: option,
                        gameType: gameType,
                        isSelected: selectedAudioOption == option
                    ) {
                        onOptionChange?(option)
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
                        .stroke(gameType.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Audio Option Button
struct AudioOptionButton: View {
    let option: GameManager.AudioOption
    let gameType: GameType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: iconForOption(option))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : ColorTheme.textSecondary)
                
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : ColorTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? gameType.color : ColorTheme.surfaceSecondary)
            )
        }
    }
    
    private func iconForOption(_ option: GameManager.AudioOption) -> String {
        switch option {
        case .chord: return "music.note.list"
        case .individual: return "dot.radiowaves.left.and.right"
        case .bass: return "speaker.wave.1"
        case .treble: return "speaker.wave.3"
        }
    }
}
