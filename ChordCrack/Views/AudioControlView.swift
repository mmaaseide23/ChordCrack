import SwiftUI

/// Professional audio control interface without animated UI elements
struct AudioControlView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 16) {
            attemptInfoSection
            
            if gameManager.currentAttempt == 5 {
                AudioOptionsSelector()
                    .environmentObject(gameManager)
            }
            
            playButton
            
            if let error = audioManager.errorMessage {
                errorDisplay(error)
            }
        }
    }
    
    // MARK: - View Components
    
    private var attemptInfoSection: some View {
        VStack(spacing: 8) {
            Text("Attempt \(gameManager.currentAttempt) of \(gameManager.maxAttempts)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(ColorTheme.primaryGreen)
            
            Text(gameManager.hintDescription)
                .font(.subheadline)
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
    
    private var playButton: some View {
        Button(action: playCurrentChord) {
            HStack(spacing: 12) {
                playButtonIcon
                playButtonText
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(playButtonBackground)
        }
        .disabled(audioManager.isLoading || gameManager.gameState != .playing || audioManager.hasPlayedThisAttempt)
    }
    
    private var playButtonIcon: some View {
        Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" :
              audioManager.isLoading ? "hourglass" : "play.circle.fill")
            .font(.title2)
            .foregroundColor(ColorTheme.textPrimary)
            .rotationEffect(.degrees(audioManager.isLoading ? 360 : 0))
            .animation(audioManager.isLoading ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                      value: audioManager.isLoading)
    }
    
    private var playButtonText: some View {
        Text(playButtonTitle)
            .fontWeight(.semibold)
            .foregroundColor(ColorTheme.textPrimary)
    }
    
    private var playButtonTitle: String {
        if audioManager.isLoading {
            return "Loading..."
        } else if audioManager.isPlaying {
            return "Playing..."
        } else if audioManager.hasPlayedThisAttempt {
            return "Already Played"
        } else if gameManager.currentAttempt == 5 {
            return "Play \(gameManager.selectedAudioOption.rawValue)"
        } else {
            return "Play Chord"
        }
    }
    
    private var playButtonBackground: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(
                LinearGradient(
                    colors: audioManager.isLoading || audioManager.hasPlayedThisAttempt ?
                        [ColorTheme.textTertiary, ColorTheme.textTertiary.opacity(0.8)] :
                        [ColorTheme.primaryGreen, ColorTheme.lightGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
    
    // MARK: - Actions
    
    private func playCurrentChord() {
        guard let chord = gameManager.currentChord else { return }
        audioManager.playChord(chord, hintType: gameManager.currentHintType, audioOption: gameManager.selectedAudioOption)
    }
}

// MARK: - Audio Options Selector

/// Audio option selection interface for attempt 5
struct AudioOptionsSelector: View {
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
                    AudioOptionButton(
                        option: option,
                        isSelected: gameManager.selectedAudioOption == option
                    ) {
                        gameManager.selectedAudioOption = option
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
}

/// Individual audio option button
struct AudioOptionButton: View {
    let option: GameManager.AudioOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconForOption(option))
                    .font(.caption)
                    .foregroundColor(isSelected ? ColorTheme.textPrimary : ColorTheme.textSecondary)
                
                Text(option.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? ColorTheme.textPrimary : ColorTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(optionButtonBackground)
        }
    }
    
    private var optionButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                isSelected ?
                LinearGradient(
                    colors: [ColorTheme.primaryGreen, ColorTheme.lightGreen],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ) :
                LinearGradient(
                    colors: [ColorTheme.surfaceSecondary, ColorTheme.surfaceSecondary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? ColorTheme.lightGreen : ColorTheme.textTertiary.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
    
    private func iconForOption(_ option: GameManager.AudioOption) -> String {
        switch option {
        case .chord: return "music.note.list"
        case .arpeggiated: return "waveform"
        case .individual: return "dot.radiowaves.left.and.right"
        case .bass: return "speaker.wave.1"
        case .treble: return "speaker.wave.3"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Audio Controls Preview")
            .font(.title)
            .foregroundColor(ColorTheme.textPrimary)
        
        AudioControlView()
            .environmentObject({
                let gm = GameManager()
                gm.currentAttempt = 5
                return gm
            }())
            .environmentObject(AudioManager())
        
        AudioControlView()
            .environmentObject({
                let gm = GameManager()
                gm.currentAttempt = 3
                return gm
            }())
            .environmentObject(AudioManager())
    }
    .padding()
    .background(ColorTheme.background)
}
