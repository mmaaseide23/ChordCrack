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
        HStack(spacing: 12) {
            // Round progress with compact ring
            ZStack {
                Circle()
                    .stroke(ColorTheme.secondaryBackground, lineWidth: 3)
                    .frame(width: 42, height: 42)

                Circle()
                    .trim(from: 0, to: CGFloat(currentRound - 1) / CGFloat(totalRounds))
                    .stroke(gameType.color, lineWidth: 3)
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: currentRound)

                VStack(spacing: 1) {
                    Text("\(currentRound)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)

                    Text("of \(totalRounds)")
                        .font(.system(size: 7))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }

            Spacer()

            // Score with animated counter
            VStack(alignment: .center, spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(ColorTheme.textSecondary)
                    .tracking(1)

                Text("\(score)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(gameType.color)
            }

            Spacer()

            // Streak with flame effect
            HStack(spacing: 6) {
                if streak >= 3 {
                    ZStack {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.orange)

                        if streak >= 5 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.red)
                                .offset(y: -6)
                        }
                    }
                }

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(streak)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(streak >= 3 ? Color.orange : ColorTheme.textPrimary)

                    Text("STREAK")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .tracking(0.5)
                }
            }

            // Always show pause button for consistency across all modes
            Button(action: {
                if let onPause = onPause {
                    onPause()
                } else {
                    onEndGame?()
                }
            }) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(ColorTheme.textSecondary)
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Unified Progress Section (Compact)
struct GameProgressSection: View {
    let gameType: GameType
    let currentRound: Int
    let totalRounds: Int
    let currentAttempt: Int
    let maxAttempts: Int
    let score: Int

    var body: some View {
        VStack(spacing: 10) {
            progressBarSection
            gameStatsRow
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

    private var progressBarSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(currentRound - 1)/\(totalRounds)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(gameType.color)

                Spacer()

                Text("Attempt \(min(currentAttempt, maxAttempts)) of \(maxAttempts)")
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTheme.secondaryBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [gameType.color, gameType.color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(
                            width: geometry.size.width * CGFloat(currentRound - 1) / CGFloat(totalRounds),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.5), value: currentRound)
                }
            }
            .frame(height: 6)
        }
    }

    private var gameStatsRow: some View {
        HStack(spacing: 12) {
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
        let points = max(60 - (currentAttempt - 1) * 10, 10)
        return GameStatPill(
            icon: "star.fill",
            value: "\(points) pts",
            label: "Available",
            color: Color.orange
        )
    }

    private var pointsPill: some View {
        return GameStatPill(
            icon: "flame.fill",
            value: "\(score)",
            label: "Score",
            color: gameType.color
        )
    }
}

// MARK: - GameStatPill Component (Compact)
struct GameStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(ColorTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Unified Audio Control Section (Compact)
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

    @State private var hasPlayedThisAttempt = false

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
        VStack(spacing: 10) {
            // Horizontal audio options for attempts 3-6
            if showAudioOptions && currentAttempt >= 3 {
                AudioOptionsSelector(
                    gameType: gameType,
                    selectedAudioOption: selectedAudioOption,
                    onOptionChange: onAudioOptionChange
                )
            }

            // Compact play button
            Button(action: {
                onPlayChord()
                hasPlayedThisAttempt = true
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        if audioManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" : "play.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }

                    Text(playButtonTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(buttonGradient)
                )
            }
            .disabled(audioManager.isLoading || hasPlayedThisAttempt || audioManager.hasPlayedForCurrentChord(currentChord))
            .scaleEffect(audioManager.isLoading || hasPlayedThisAttempt || audioManager.hasPlayedForCurrentChord(currentChord) ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: audioManager.isLoading)

            // Error display
            if let error = audioManager.errorMessage {
                errorDisplay(error)
            }
        }
        .onChange(of: currentAttempt) { _, _ in
            hasPlayedThisAttempt = false
        }
        .onChange(of: currentChord) { _, _ in
            hasPlayedThisAttempt = false
        }
    }

    private var playButtonTitle: String {
        if audioManager.isLoading {
            return "Loading..."
        } else if audioManager.isPlaying {
            return "Playing..."
        } else if hasPlayedThisAttempt || audioManager.hasPlayedForCurrentChord(currentChord) {
            return "Audio Played"
        } else if currentAttempt >= 3 && showAudioOptions {
            return "Play \(selectedAudioOption.rawValue)"
        } else {
            return "Play Mystery Chord"
        }
    }

    private var buttonGradient: LinearGradient {
        if audioManager.isLoading || hasPlayedThisAttempt || audioManager.hasPlayedForCurrentChord(currentChord) {
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
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ColorTheme.error)
                .font(.system(size: 11))

            Text(error)
                .foregroundColor(ColorTheme.error)
                .font(.system(size: 11))
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.error.opacity(0.1))
        )
    }
}

// MARK: - Audio Options Selector (Horizontal Pills)
struct AudioOptionsSelector: View {
    let gameType: GameType
    let selectedAudioOption: GameManager.AudioOption
    let onOptionChange: ((GameManager.AudioOption) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
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

// MARK: - AudioManager Extension for hasPlayedForCurrentChord
extension AudioManager {
    func hasPlayedForCurrentChord(_ chord: ChordType?) -> Bool {
        guard let chord = chord else { return false }
        let chordKey = "\(chord.rawValue)-\(currentSessionId.uuidString)"
        return playedChords.contains(chordKey)
    }
}
