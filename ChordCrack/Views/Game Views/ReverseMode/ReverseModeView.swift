import SwiftUI

// MARK: - Main Reverse Mode View
struct ReverseModeView: View {
    @StateObject private var reverseManager = ReverseModeManager()
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    
    let gameMode: GameType
    let practiceCategory: ChordCategory?
    
    init(gameMode: GameType = .dailyChallenge, practiceCategory: ChordCategory? = nil) {
        self.gameMode = gameMode
        self.practiceCategory = practiceCategory
    }
    
    var body: some View {
        ZStack {
            ColorTheme.reverseBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header section
                    headerSection
                    
                    // Progress section
                    progressSection
                    
                    // Target chord display
                    chordDisplaySection
                    
                    // Interactive fretboard
                    fretboardSection
                    
                    // Hints section
                    hintSection
                    
                    // Game status section
                    statusSection
                    
                    // Action buttons
                    if reverseManager.gameState == .playing {
                        actionButtons
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupGame()
        }
    }
    
    private func setupGame() {
        reverseManager.setAudioManager(audioManager)
        reverseManager.setUserDataManager(userDataManager)
        
        if let category = practiceCategory {
            reverseManager.startPracticeSession(for: category)
        } else {
            reverseManager.startNewGame(mode: gameMode)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reverse Mode")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text(gameModeName)
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.primaryPurple)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Score
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(reverseManager.score)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.brightPurple)
                    Text("Score")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                
                // Streak
                if reverseManager.currentStreak > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.orange)
                            Text("\(reverseManager.currentStreak)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.orange)
                        }
                        Text("Streak")
                            .font(.system(size: 10))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
                
                // Exit button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Round \(reverseManager.currentRound)/\(reverseManager.totalRounds)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorTheme.textSecondary)
                
                Spacer()
                
                Text("Attempt \(reverseManager.currentAttempt)/\(reverseManager.maxAttempts)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTheme.reverseSecondaryBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTheme.reversePrimaryGradient)
                        .frame(
                            width: geometry.size.width * reverseManager.progressPercentage,
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.reverseCardBackground)
        )
    }
    
    // MARK: - Chord Display Section
    private var chordDisplaySection: some View {
        VStack(spacing: 12) {
            Text("Build this chord:")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
            
            HStack(spacing: 16) {
                // Chord name
                Text(reverseManager.targetChord?.displayName ?? "")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(ColorTheme.brightPurple)
                
                // Chord type badge
                if let chord = reverseManager.targetChord {
                    VStack(spacing: 4) {
                        Text(chord.category.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ColorTheme.lightPurple)
                        
                        Text(chord.difficultyLevel)
                            .font(.system(size: 10))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorTheme.primaryPurple.opacity(0.2))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.reverseCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorTheme.primaryPurple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Fretboard Section
    private var fretboardSection: some View {
        VStack(spacing: 16) {
            ReverseModeInteractiveFretboard(
                placedFingers: $reverseManager.placedFingers,
                openStrings: $reverseManager.openStrings,
                mutedStrings: $reverseManager.mutedStrings,
                showCorrectPositions: reverseManager.showingCorrectPositions,
                correctPositions: reverseManager.correctPositions,
                incorrectPositions: reverseManager.incorrectPositions,
                missingPositions: reverseManager.missingPositions,
                showTheoryHints: reverseManager.showTheoryHints,
                isDisabled: reverseManager.gameState != .playing,
                onToggleFinger: reverseManager.toggleFinger,
                onToggleString: reverseManager.toggleStringState
            )
            .frame(height: 320)
            
            // Chord type indicator
            if let _ = reverseManager.targetChord {
                HStack(spacing: 8) {
                    Image(systemName: "guitars.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.primaryPurple)
                    
                    Text("Reverse Mode - Build the Chord")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Spacer()
                    
                    Text("Tap frets to place fingers")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ColorTheme.primaryPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ColorTheme.primaryPurple.opacity(0.15))
                        )
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Hint Section
    private var hintSection: some View {
        HStack(spacing: 12) {
            // Play Sound Hint
            Button(action: {
                reverseManager.useSoundHint()
            }) {
                VStack(spacing: 6) {
                    Image(systemName: reverseManager.hasUsedSoundHint ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundColor(reverseManager.hasUsedSoundHint ? ColorTheme.textTertiary : ColorTheme.textPrimary)
                    
                    Text("Play Sound")
                        .font(.caption)
                        .foregroundColor(reverseManager.hasUsedSoundHint ? ColorTheme.textTertiary : ColorTheme.textSecondary)
                    
                    if reverseManager.hasUsedSoundHint {
                        Text("-10 pts")
                            .font(.caption2)
                            .foregroundColor(Color.orange)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ColorTheme.reverseSecondaryBackground.opacity(reverseManager.hasUsedSoundHint ? 0.5 : 1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ColorTheme.primaryPurple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .disabled(reverseManager.hasUsedSoundHint || reverseManager.gameState != .playing)
            
            // Theory Hint
            Button(action: {
                reverseManager.toggleTheoryHint()
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundColor(reverseManager.showTheoryHints ? ColorTheme.primaryPurple : ColorTheme.textPrimary)
                    
                    Text("Theory Help")
                        .font(.caption)
                        .foregroundColor(reverseManager.showTheoryHints ? ColorTheme.primaryPurple : ColorTheme.textSecondary)
                    
                    if reverseManager.hasUsedTheoryHint {
                        Text("-15 pts")
                            .font(.caption2)
                            .foregroundColor(Color.orange)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(reverseManager.showTheoryHints ?
                              ColorTheme.primaryPurple.opacity(0.2) :
                              ColorTheme.reverseSecondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ColorTheme.primaryPurple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .disabled(reverseManager.gameState != .playing)
        }
        .padding(.horizontal)
        
        // Theory explanation when active
        .overlay(alignment: .bottom) {
            if reverseManager.showTheoryHints, let chord = reverseManager.targetChord {
                theoryExplanation(for: chord)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Theory Explanation
    private func theoryExplanation(for chord: ChordType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color.yellow)
                Text("Chord Theory")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
            }
            
            Text(getTheoryText(for: chord))
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.reverseCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }
    
    // MARK: - Status Section
    @ViewBuilder
    private var statusSection: some View {
        switch reverseManager.gameState {
        case .playing:
            VStack(spacing: 8) {
                Text("Place Your Fingers")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("Tap the fretboard to build the chord")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            .padding(.vertical, 12)
            
        case .answered:
            ReverseResultView()
                .environmentObject(reverseManager)
            
        case .completed:
            ReverseCompletedView()
                .environmentObject(reverseManager)
                .environmentObject(userDataManager)
                
        default:
            EmptyView()
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                reverseManager.clearBoard()
            }) {
                Text("Clear")
                    .fontWeight(.semibold)
                    .foregroundColor(ColorTheme.error)
                    .frame(width: 100)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTheme.error, lineWidth: 2)
                    )
            }
            
            Button(action: {
                reverseManager.submitAnswer()
            }) {
                Text("Check Chord")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTheme.reversePrimaryGradient)
                    )
            }
            .disabled(reverseManager.placedFingers.isEmpty &&
                     reverseManager.openStrings.isEmpty &&
                     reverseManager.mutedStrings.isEmpty)
        }
    }
    
    // MARK: - Helper Properties
    private var gameModeName: String {
        switch gameMode {
        case .dailyChallenge:
            return "Daily Challenge"
        case .basicPractice:
            return "Basic Practice"
        case .powerPractice:
            return "Power Chords"
        case .barrePractice:
            return "Barre Chords"
        case .bluesPractice:
            return "Blues Chords"
        case .mixedPractice:
            return "Mixed Practice"
        case .speedRound:
            return "Speed Round"
        }
    }
    
    private func getTheoryText(for chord: ChordType) -> String {
        switch chord.category {
        case .basic:
            return "Major chords use the 1st, 3rd, and 5th notes of the scale. Minor chords flatten the 3rd. Place your fingers on the exact frets shown in the chord diagram."
        case .power:
            return "Power chords use only the root and 5th notes, creating a powerful, ambiguous sound. They typically use 2-3 strings and are moveable shapes."
        case .barre:
            return "Barre chords use one finger to press multiple strings at the same fret. The index finger acts as a moveable capo while other fingers form the chord shape."
        case .blues:
            return "7th chords add the flatted 7th note to create tension and bluesy sound. Pay attention to which strings are played and which are muted."
        }
    }
}
