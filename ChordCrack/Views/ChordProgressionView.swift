import SwiftUI

/// Chord progression training mode - identify sequences of chords
struct ChordProgressionView: View {
    @StateObject private var progressionManager = ChordProgressionManager()
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                difficultyIndicator
                sequenceDisplaySection
                audioControlsSection
                gameStatusSection
                
                if progressionManager.gameState == .playing || progressionManager.gameState == .answered {
                    progressionSelectionSection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Chord Progressions")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            progressionManager.startProgressionPractice()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sequence \(progressionManager.currentQuestion)/\(progressionManager.totalQuestions)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.blue)
                    
                    Text("Score: \(progressionManager.score)")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                
                Spacer()
                
                Button("End Practice") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.system(size: 13))
                .foregroundColor(ColorTheme.textSecondary)
            }
            
            ProgressView(value: Double(progressionManager.currentQuestion - 1), total: Double(progressionManager.totalQuestions))
                .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
    
    private var difficultyIndicator: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
            
            Text("Current: \(progressionManager.currentProgressionType.displayName)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textPrimary)
            
            Spacer()
            
            Text("\(progressionManager.currentProgression.count) chords")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var sequenceDisplaySection: some View {
        VStack(spacing: 16) {
            Text("Listen to the chord sequence:")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ColorTheme.textPrimary)
            
            // Visual progression display
            HStack(spacing: 8) {
                ForEach(0..<progressionManager.currentProgression.count, id: \.self) { index in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(progressionManager.playbackPosition == index ? Color.blue : ColorTheme.textTertiary.opacity(0.3))
                            .frame(width: 16, height: 16)
                        
                        Text("Chord \(index + 1)")
                            .font(.system(size: 10))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    if index < progressionManager.currentProgression.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.secondaryBackground)
            )
        }
    }
    
    private var audioControlsSection: some View {
        VStack(spacing: 12) {
            Text("Attempt \(progressionManager.currentAttempt) of \(progressionManager.maxAttempts)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.blue)
            
            Button(action: playProgression) {
                HStack(spacing: 12) {
                    Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" :
                          audioManager.isLoading ? "hourglass" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(audioManager.isLoading ? "Loading..." :
                         audioManager.isPlaying ? "Playing Sequence..." : "Play Chord Progression")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(audioManager.isLoading ? ColorTheme.textTertiary : Color.blue)
                )
            }
            .disabled(audioManager.isLoading || progressionManager.gameState != .playing)
        }
    }
    
    @ViewBuilder
    private var gameStatusSection: some View {
        switch progressionManager.gameState {
        case .playing:
            Text("Identify this chord progression!")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        case .answered:
            ProgressionResultView()
                .environmentObject(progressionManager)
        case .completed:
            ProgressionCompletedView()
                .environmentObject(progressionManager)
        default:
            EmptyView()
        }
    }
    
    private var progressionSelectionSection: some View {
        ProgressionSelectionView()
            .environmentObject(progressionManager)
    }
    
    private func playProgression() {
        progressionManager.playCurrentProgression(audioManager: audioManager)
    }
}

// MARK: - Chord Progression Manager

class ChordProgressionManager: ObservableObject {
    @Published var currentQuestion = 1
    @Published var totalQuestions = 8
    @Published var score = 0
    @Published var currentProgression: [ChordType] = []
    @Published var currentProgressionType: ProgressionType = .simple
    @Published var selectedProgression: ProgressionPattern?
    @Published var gameState: GameState = .waiting
    @Published var currentAttempt = 1
    @Published var maxAttempts = 3
    @Published var attempts: [ProgressionPattern?] = []
    @Published var playbackPosition = -1
    
    enum GameState {
        case waiting
        case playing
        case answered
        case completed
    }
    
    func startProgressionPractice() {
        currentQuestion = 1
        score = 0
        gameState = .waiting
        startNewProgression()
    }
    
    func startNewProgression() {
        guard currentQuestion <= totalQuestions else {
            gameState = .completed
            return
        }
        
        // Determine difficulty based on question
        currentProgressionType = getProgressionType(for: currentQuestion)
        
        // Generate progression based on type
        let pattern = ProgressionPattern.getPatterns(for: currentProgressionType).randomElement()!
        currentProgression = pattern.generateChords()
        selectedProgression = nil
        currentAttempt = 1
        attempts = Array(repeating: nil, count: maxAttempts)
        gameState = .playing
        playbackPosition = -1
    }
    
    private func getProgressionType(for question: Int) -> ProgressionType {
        switch question {
        case 1...2: return .simple      // I-V or vi-IV
        case 3...4: return .popular     // I-V-vi-IV, vi-IV-I-V
        case 5...6: return .jazz        // ii-V-I, I-vi-ii-V
        default: return .complex        // Mixed progressions
        }
    }
    
    func submitGuess(_ pattern: ProgressionPattern) {
        guard gameState == .playing, currentAttempt <= maxAttempts else { return }
        
        selectedProgression = pattern
        attempts[currentAttempt - 1] = pattern
        
        if pattern.matches(progression: currentProgression) {
            let points = max(100 - (currentAttempt - 1) * 30, 20)
            score += points
            gameState = .answered
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.nextProgression()
            }
        } else {
            currentAttempt += 1
            
            if currentAttempt > maxAttempts {
                gameState = .answered
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    self.nextProgression()
                }
            }
        }
    }
    
    func nextProgression() {
        currentQuestion += 1
        startNewProgression()
    }
    
    func playCurrentProgression(audioManager: AudioManager) {
        playbackPosition = 0
        playChordInSequence(index: 0, audioManager: audioManager)
    }
    
    private func playChordInSequence(index: Int, audioManager: AudioManager) {
        guard index < currentProgression.count else {
            playbackPosition = -1
            return
        }
        
        playbackPosition = index
        let chord = currentProgression[index]
        
        // For chord progressions, always use standard playback settings
        // This mode doesn't need hints since it's about recognizing sequences
        Task { @MainActor in
            audioManager.playChord(
                chord,
                hintType: .chordNoFingers,  // Standard chord playback for progressions
                audioOption: .chord          // Always play full chord for progressions
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.playChordInSequence(index: index + 1, audioManager: audioManager)
        }
    }
}

// MARK: - Progression Data Models

enum ProgressionType: CaseIterable {
    case simple
    case popular
    case jazz
    case complex
    
    var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .popular: return "Popular"
        case .jazz: return "Jazz"
        case .complex: return "Complex"
        }
    }
}

struct ProgressionPattern: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let romanNumerals: [String]
    let type: ProgressionType
    
    // Implement Equatable - compare by name and roman numerals since id is always unique
    static func == (lhs: ProgressionPattern, rhs: ProgressionPattern) -> Bool {
        return lhs.name == rhs.name && lhs.romanNumerals == rhs.romanNumerals && lhs.type == rhs.type
    }
    
    static func getPatterns(for type: ProgressionType) -> [ProgressionPattern] {
        switch type {
        case .simple:
            return [
                ProgressionPattern(name: "I-V", romanNumerals: ["I", "V"], type: .simple),
                ProgressionPattern(name: "vi-IV", romanNumerals: ["vi", "IV"], type: .simple),
                ProgressionPattern(name: "I-vi", romanNumerals: ["I", "vi"], type: .simple)
            ]
        case .popular:
            return [
                ProgressionPattern(name: "I-V-vi-IV", romanNumerals: ["I", "V", "vi", "IV"], type: .popular),
                ProgressionPattern(name: "vi-IV-I-V", romanNumerals: ["vi", "IV", "I", "V"], type: .popular),
                ProgressionPattern(name: "I-vi-IV-V", romanNumerals: ["I", "vi", "IV", "V"], type: .popular)
            ]
        case .jazz:
            return [
                ProgressionPattern(name: "ii-V-I", romanNumerals: ["ii", "V", "I"], type: .jazz),
                ProgressionPattern(name: "I-vi-ii-V", romanNumerals: ["I", "vi", "ii", "V"], type: .jazz),
                ProgressionPattern(name: "vi-ii-V-I", romanNumerals: ["vi", "ii", "V", "I"], type: .jazz)
            ]
        case .complex:
            return [
                ProgressionPattern(name: "I-iii-vi-IV", romanNumerals: ["I", "iii", "vi", "IV"], type: .complex),
                ProgressionPattern(name: "vi-V-IV-V", romanNumerals: ["vi", "V", "IV", "V"], type: .complex)
            ]
        }
    }
    
    func generateChords() -> [ChordType] {
        // Convert roman numerals to actual chords in C major
        return romanNumerals.compactMap { numeral in
            switch numeral {
            case "I": return .cMajor
            case "ii": return .dMinor
            case "iii": return .eMinor
            case "IV": return .fMajor
            case "V": return .gMajor
            case "vi": return .aMinor
            case "vii°": return .bMinor // Simplified
            default: return nil
            }
        }
    }
    
    func matches(progression: [ChordType]) -> Bool {
        let generatedChords = generateChords()
        return progression.count == generatedChords.count &&
               zip(progression, generatedChords).allSatisfy { $0 == $1 }
    }
}

// MARK: - Progression Selection View

struct ProgressionSelectionView: View {
    @EnvironmentObject var progressionManager: ChordProgressionManager
    
    private let availablePatterns = ProgressionPattern.getPatterns(for: .simple) +
                                   ProgressionPattern.getPatterns(for: .popular) +
                                   ProgressionPattern.getPatterns(for: .jazz) +
                                   ProgressionPattern.getPatterns(for: .complex)
    
    var body: some View {
        VStack(spacing: 16) {
            if !progressionManager.attempts.isEmpty {
                previousAttemptsView
            }
            
            VStack(spacing: 8) {
                Text("Select the chord progression:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 2)
                    .cornerRadius(1)
            }
            
            // Group patterns by type
            LazyVStack(spacing: 12) {
                ForEach(ProgressionType.allCases, id: \.self) { type in
                    progressionTypeSection(type)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var previousAttemptsView: some View {
        VStack(spacing: 12) {
            Text("Previous Attempts:")
                .font(.system(size: 14))
                .foregroundColor(ColorTheme.textSecondary)
            
            HStack(spacing: 12) {
                ForEach(0..<progressionManager.maxAttempts, id: \.self) { index in
                    Circle()
                        .fill(attemptColor(for: index))
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private func progressionTypeSection(_ type: ProgressionType) -> some View {
        let patterns = ProgressionPattern.getPatterns(for: type)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(typeColor(type))
                    .frame(width: 8, height: 8)
                
                Text(type.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(typeColor(type))
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(patterns) { pattern in
                    ProgressionButton(pattern: pattern)
                        .environmentObject(progressionManager)
                }
            }
        }
    }
    
    private func typeColor(_ type: ProgressionType) -> Color {
        switch type {
        case .simple: return ColorTheme.primaryGreen
        case .popular: return Color.orange
        case .jazz: return Color.purple
        case .complex: return Color.red
        }
    }
    
    private func attemptColor(for index: Int) -> Color {
        if index < progressionManager.attempts.count {
            if let attempt = progressionManager.attempts[index] {
                let isCorrect = attempt.matches(progression: progressionManager.currentProgression)
                return isCorrect ? Color.blue : ColorTheme.error
            }
        } else if index == progressionManager.currentAttempt - 1 {
            return Color.blue.opacity(0.5)
        }
        return ColorTheme.textTertiary.opacity(0.3)
    }
}

struct ProgressionButton: View {
    let pattern: ProgressionPattern
    @EnvironmentObject var progressionManager: ChordProgressionManager
    
    private var buttonColor: Color {
        if progressionManager.gameState == .answered {
            if pattern.matches(progression: progressionManager.currentProgression) {
                return Color.blue
            } else if pattern == progressionManager.selectedProgression {
                return ColorTheme.error
            }
        } else if pattern == progressionManager.selectedProgression {
            return Color.blue.opacity(0.7)
        }
        return ColorTheme.secondaryBackground
    }
    
    var body: some View {
        Button(action: { progressionManager.submitGuess(pattern) }) {
            VStack(spacing: 4) {
                Text(pattern.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(pattern.romanNumerals.joined(separator: "-"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(buttonColor)
            )
        }
        .disabled(progressionManager.gameState != .playing)
    }
}

// MARK: - Progression Result Views

struct ProgressionResultView: View {
    @EnvironmentObject var progressionManager: ChordProgressionManager
    
    var body: some View {
        VStack(spacing: 16) {
            let isCorrect = progressionManager.selectedProgression?.matches(progression: progressionManager.currentProgression) ?? false
            
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(isCorrect ? Color.blue : ColorTheme.error)
            
            Text(isCorrect ? "Correct!" : "Wrong!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isCorrect ? Color.blue : ColorTheme.error)
            
            if !isCorrect {
                VStack(spacing: 8) {
                    Text("The sequence was:")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    HStack(spacing: 8) {
                        ForEach(progressionManager.currentProgression, id: \.id) { chord in
                            Text(chord.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.2))
                                )
                        }
                    }
                }
            }
            
            if isCorrect {
                let points = max(100 - (progressionManager.currentAttempt - 1) * 30, 20)
                Text("+\(points) points")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                    .foregroundColor(Color.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}

struct ProgressionCompletedView: View {
    @EnvironmentObject var progressionManager: ChordProgressionManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(Color.blue)
            
            Text("Progression Training Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            VStack(spacing: 8) {
                Text("Final Score: \(progressionManager.score)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("Sequence Recognition Master")
                    .font(.system(size: 16))
                    .foregroundColor(Color.blue)
            }
            
            HStack(spacing: 16) {
                Button("Play Again") {
                    progressionManager.startProgressionPractice()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(color: Color.blue))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}
