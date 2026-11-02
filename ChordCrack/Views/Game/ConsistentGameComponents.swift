import SwiftUI

struct GameHeaderView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let gameType: GameType
    let currentRound: Int
    let totalRounds: Int
    let score: Int
    let streak: Int
    let showPauseButton: Bool
    let onPause: (() -> Void)?
    let onEndGame: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                roundRing
                Spacer(minLength: 8)
                if !dynamicTypeSize.isAccessibilitySize {
                    scoreLabel
                    Spacer(minLength: 8)
                    streakLabel
                }
                if showPauseButton {
                    Button {
                        HapticManager.shared.buttonTap()
                        if let onPause { onPause() } else { onEndGame?() }
                    } label: {
                        Image(systemName: "pause.circle.fill").font(.system(size: 25))
                            .foregroundStyle(ColorTheme.textSecondary).frame(width: 44, height: 44)
                    }.buttonStyle(StudioPressStyle()).accessibilityLabel("Pause session").accessibilityIdentifier("game.pause")
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) { scoreLabel; streakLabel }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.vertical, 8)
    }

    private var roundRing: some View {
        ZStack {
            Circle().stroke(ColorTheme.secondaryBackground, lineWidth: 3)
            Circle().trim(from: 0, to: CGFloat(max(0, min(currentRound - 1, totalRounds))) / CGFloat(max(1, totalRounds)))
                .stroke(gameType.color, lineWidth: 3).rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(min(currentRound, totalRounds))").font(.system(size: 18, weight: .bold)).foregroundStyle(ColorTheme.textPrimary)
                    .accessibilityLabel("Round \(min(currentRound, totalRounds)) of \(totalRounds)")
                Text("of \(totalRounds)").font(.system(size: 10)).foregroundStyle(ColorTheme.textSecondary).accessibilityHidden(true)
            }
        }.frame(width: 54, height: 54)
    }
    private var scoreLabel: some View {
        VStack(spacing: 3) {
            Text("SCORE").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(ColorTheme.textSecondary)
            Text("\(score)").font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(gameType.color)
        }.accessibilityElement(children: .combine)
    }
    private var streakLabel: some View {
        VStack(spacing: 3) {
            Label("\(streak)", systemImage: "flame.fill").font(.headline.monospacedDigit()).foregroundStyle(streak >= 3 ? Color.orange : ColorTheme.textPrimary)
            Text("STREAK").font(.caption2.weight(.bold)).foregroundStyle(ColorTheme.textSecondary)
        }.accessibilityElement(children: .combine)
    }
}

struct GameProgressSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let gameType: GameType
    let currentRound: Int
    let totalRounds: Int
    let currentAttempt: Int
    let maxAttempts: Int
    let score: Int
    var availablePoints: Int? = nil

    var body: some View {
        VStack(spacing: 12) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout())) {
                Text("\(gameType.displayName) Progress").font(.subheadline.weight(.semibold)).foregroundStyle(ColorTheme.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Text("\(max(0, min(currentRound - 1, totalRounds)))/\(totalRounds) Complete")
                    .font(.caption).foregroundStyle(ColorTheme.textSecondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: Double(max(0, min(currentRound - 1, totalRounds))), total: Double(max(1, totalRounds)))
                .tint(gameType.color).accessibilityLabel("Session progress")
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
                GameStatPill(icon: "music.note", value: "\(min(currentRound, totalRounds)) of \(totalRounds)", label: "Round", color: gameType.color)
                GameStatPill(icon: "arrow.counterclockwise", value: "\(min(currentAttempt, maxAttempts)) of \(maxAttempts)", label: "Attempt", color: ColorTheme.blues)
                if let availablePoints {
                    GameStatPill(icon: "star.fill", value: "\(availablePoints) pts", label: "Available", color: ColorTheme.barre)
                        .accessibilityIdentifier("game.available-points")
                }
            }
        }
        .padding(14).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gameType.color.opacity(0.3), lineWidth: 1))
    }
}

struct GameStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(color).accessibilityHidden(true)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(ColorTheme.textPrimary)
            Text(label).font(.caption2).foregroundStyle(ColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 6)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

struct GameAudioControlSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let gameType: GameType
    let currentAttempt: Int
    let maxAttempts: Int
    let showAudioOptions: Bool
    @ObservedObject var audioManager: AudioManager
    let currentChord: ChordType?
    let currentHintType: GameManager.HintType
    let selectedAudioOption: GameManager.AudioOption
    let onPlayChord: () -> Void
    let onAudioOptionChange: ((GameManager.AudioOption) -> Void)?

    init(gameType: GameType, currentAttempt: Int, maxAttempts: Int, showAudioOptions: Bool,
         audioManager: AudioManager, currentChord: ChordType?, currentHintType: GameManager.HintType,
         selectedAudioOption: GameManager.AudioOption, onPlayChord: @escaping () -> Void,
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

    private var played: Bool {
        audioManager.hasPlayedForCurrentChord(currentChord)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showAudioOptions && currentAttempt >= 3 {
                Text("Choose what to hear").font(.caption.weight(.medium)).foregroundStyle(ColorTheme.textSecondary)
                AudioOptionsSelector(gameType: gameType, selectedAudioOption: selectedAudioOption, onOptionChange: onAudioOptionChange)
            }
            Button {
                HapticManager.shared.buttonTap()
                if audioManager.errorMessage != nil { audioManager.resetForNewAttempt() }
                onPlayChord()
            } label: {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    Group {
                        if audioManager.isLoading {
                            ProgressView().tint(ColorTheme.background)
                        } else {
                            Image(systemName: audioManager.isPlaying ? "waveform" : played ? "checkmark" : "play.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .symbolEffect(.bounce, value: audioManager.isPlaying && !reduceMotion)
                        }
                    }.frame(width: 32, height: 32)
                    Text(playButtonTitle).font(.headline).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(played ? ColorTheme.textPrimary : ColorTheme.background)
                .padding(.horizontal, 20).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 56)
                .background(played ? ColorTheme.secondaryBackground : gameType.color,
                            in: RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 18 : 28))
                .overlay(RoundedRectangle(cornerRadius: dynamicTypeSize.isAccessibilitySize ? 18 : 28).stroke(gameType.color.opacity(played ? 0.5 : 0), lineWidth: 1))
            }
            .buttonStyle(StudioPressStyle())
            .disabled(audioManager.isLoading || audioManager.isPlaying || played || currentChord == nil)
            .accessibilityIdentifier("game.listen")
            Text(played ? "Choose the chord you heard below" : "One listen with each attempt")
                .font(.caption).foregroundStyle(ColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let error = audioManager.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(ColorTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var playButtonTitle: String {
        if audioManager.isLoading { return "Loading audio" }
        if audioManager.isPlaying { return "Listen to the chord" }
        if audioManager.errorMessage != nil { return "Try audio again" }
        if played { return "Your turn" }
        if currentAttempt >= 3 && showAudioOptions { return "Play \(selectedAudioOption.rawValue)" }
        return "Play Mystery Chord"
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
                        HapticManager.shared.selectionChanged()
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
                    .foregroundColor(isSelected ? ColorTheme.background : ColorTheme.textSecondary)
                
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? ColorTheme.background : ColorTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? gameType.color : ColorTheme.surfaceSecondary)
            )
        }
        .buttonStyle(StudioPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
