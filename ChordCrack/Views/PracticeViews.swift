import SwiftUI

// MARK: - Base Practice View
struct PracticeView: View {
    let category: ChordCategory
    @StateObject private var practiceManager = PracticeManager()
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                practiceHeaderView
                
                GuitarNeckView(
                    chord: practiceManager.currentChord,
                    currentAttempt: practiceManager.currentAttempt,
                    jumbledPositions: practiceManager.jumbledFingerPositions,
                    revealedFingerIndex: practiceManager.revealedFingerIndex
                )
                
                PracticeAudioControlView(category: category)
                    .environmentObject(practiceManager)
                    .environmentObject(audioManager)
                
                if practiceManager.gameState == .playing {
                    Text("Listen and identify the \(category.rawValue.lowercased()) chord!")
                        .font(.headline)
                        .foregroundColor(ColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if practiceManager.gameState == .answered {
                    PracticeResultView(category: category)
                        .environmentObject(practiceManager)
                } else if practiceManager.gameState == .completed {
                    PracticeCompletedView(category: category)
                        .environmentObject(practiceManager)
                }
                
                if practiceManager.gameState == .playing || practiceManager.gameState == .answered {
                    PracticeChordSelectionView(category: category)
                        .environmentObject(practiceManager)
                }
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("\(category.displayName) Practice")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            practiceManager.startPracticeSession(for: category)
        }
        .onChange(of: practiceManager.currentAttempt) { oldValue, newValue in
            audioManager.resetForNewAttempt()
        }
    }
    
    private var practiceHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Question \(practiceManager.currentQuestion)/\(practiceManager.totalQuestions)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(category.color)
                    
                    Text("Score: \(practiceManager.score)")
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
            
            ProgressView(value: Double(practiceManager.currentQuestion - 1), total: Double(practiceManager.totalQuestions))
                .progressViewStyle(LinearProgressViewStyle(tint: category.color))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}

// MARK: - Practice Manager
class PracticeManager: ObservableObject {
    @Published var currentQuestion = 1
    @Published var totalQuestions = 10
    @Published var score = 0
    @Published var currentChord: ChordType?
    @Published var selectedChord: ChordType?
    @Published var gameState: GameState = .waiting
    @Published var currentAttempt = 1
    @Published var maxAttempts = 4
    @Published var attempts: [ChordType?] = []
    @Published var jumbledFingerPositions: [Int] = []
    @Published var revealedFingerIndex: Int = -1
    @Published var practiceCategory: ChordCategory = .basic
    
    enum GameState {
        case waiting
        case playing
        case answered
        case completed
    }
    
    func startPracticeSession(for category: ChordCategory) {
        practiceCategory = category
        currentQuestion = 1
        score = 0
        gameState = .waiting
        startNewQuestion()
    }
    
    func startNewQuestion() {
        guard currentQuestion <= totalQuestions else {
            gameState = .completed
            return
        }
        
        let availableChords: [ChordType]
        switch practiceCategory {
        case .basic:
            availableChords = ChordType.basicChords
        case .barre:
            availableChords = ChordType.barreChords
        case .blues:
            availableChords = ChordType.bluesChords
        case .power:
            availableChords = ChordType.powerChords
        }
        
        currentChord = availableChords.randomElement()
        selectedChord = nil
        currentAttempt = 1
        attempts = Array(repeating: nil, count: maxAttempts)
        gameState = .playing
        jumbledFingerPositions = []
        revealedFingerIndex = -1
    }
    
    func submitGuess(_ guess: ChordType) {
        guard gameState == .playing, currentAttempt <= maxAttempts else { return }
        
        selectedChord = guess
        attempts[currentAttempt - 1] = guess
        
        if guess == currentChord {
            let points = max(40 - (currentAttempt - 1) * 10, 10)
            score += points
            gameState = .answered
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.nextQuestion()
            }
        } else {
            currentAttempt += 1
            
            if currentAttempt == 3 {
                generateJumbledFingerPositions()
            } else if currentAttempt == 4 {
                revealRandomFingerPosition()
            }
            
            if currentAttempt > maxAttempts {
                gameState = .answered
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.nextQuestion()
                }
            }
        }
    }
    
    func nextQuestion() {
        currentQuestion += 1
        startNewQuestion()
    }
    
    private func generateJumbledFingerPositions() {
        guard let chord = currentChord else { return }
        let correctPositions = chord.fingerPositions.map { $0.fret }
        jumbledFingerPositions = correctPositions.shuffled()
    }
    
    private func revealRandomFingerPosition() {
        guard let chord = currentChord else { return }
        let fingerPositions = chord.fingerPositions
        if !fingerPositions.isEmpty {
            revealedFingerIndex = Int.random(in: 0..<fingerPositions.count)
        }
    }
}

// MARK: - Practice Audio Control View
struct PracticeAudioControlView: View {
    let category: ChordCategory
    @EnvironmentObject var practiceManager: PracticeManager
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Attempt \(practiceManager.currentAttempt) of \(practiceManager.maxAttempts)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(category.color)
            
            Button(action: playCurrentChord) {
                HStack(spacing: 12) {
                    Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" :
                          audioManager.isLoading ? "hourglass" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(audioManager.isLoading ? 360 : 0))
                        .animation(audioManager.isLoading ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: audioManager.isLoading)
                    
                    Text(audioManager.isLoading ? "Loading..." :
                         audioManager.isPlaying ? "Playing..." :
                         audioManager.hasPlayedThisAttempt ? "Play Again" : "Play \(category.rawValue) Chord")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(audioManager.isLoading ? ColorTheme.textTertiary : category.color)
                )
            }
            .disabled(audioManager.isLoading || practiceManager.gameState != .playing)
        }
    }
    
    private func playCurrentChord() {
        guard let chord = practiceManager.currentChord else { return }
        audioManager.playChord(chord, hintType: .chordNoFingers, audioOption: .chord)
    }
}

// MARK: - Practice Result View
struct PracticeResultView: View {
    let category: ChordCategory
    @EnvironmentObject var practiceManager: PracticeManager
    
    var body: some View {
        VStack(spacing: 16) {
            let isCorrect = practiceManager.selectedChord == practiceManager.currentChord
            
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(isCorrect ? category.color : ColorTheme.error)
            
            Text(isCorrect ? "Correct!" : "Wrong!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isCorrect ? category.color : ColorTheme.error)
            
            if !isCorrect {
                Text("Correct answer: \(practiceManager.currentChord?.displayName ?? "")")
                    .font(.system(size: 16))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            
            let points = isCorrect ? max(40 - (practiceManager.currentAttempt - 1) * 10, 10) : 0
            if points > 0 {
                Text("+\(points) points")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(category.color.opacity(0.2))
                    )
                    .foregroundColor(category.color)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}

// MARK: - Practice Completed View
struct PracticeCompletedView: View {
    let category: ChordCategory
    @EnvironmentObject var practiceManager: PracticeManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(category.color)
            
            Text("Practice Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            VStack(spacing: 8) {
                Text("Final Score: \(practiceManager.score)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("\(category.displayName) Mastery")
                    .font(.system(size: 16))
                    .foregroundColor(category.color)
            }
            
            HStack(spacing: 16) {
                Button("Play Again") {
                    practiceManager.startPracticeSession(for: category)
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(color: category.color))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}

// MARK: - Practice Chord Selection View
struct PracticeChordSelectionView: View {
    let category: ChordCategory
    @EnvironmentObject var practiceManager: PracticeManager
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var availableChords: [ChordType] {
        switch category {
        case .basic: return ChordType.basicChords
        case .barre: return ChordType.barreChords
        case .blues: return ChordType.bluesChords
        case .power: return ChordType.powerChords
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if !practiceManager.attempts.isEmpty {
                VStack(spacing: 12) {
                    Text("Previous Attempts:")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    HStack(spacing: 12) {
                        ForEach(0..<practiceManager.maxAttempts, id: \.self) { index in
                            Circle()
                                .fill(attemptColor(for: index))
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            
            VStack(spacing: 8) {
                Text("Select the \(category.rawValue.lowercased()) chord:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Rectangle()
                    .fill(category.color)
                    .frame(width: 60, height: 2)
                    .cornerRadius(1)
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(availableChords) { chord in
                    PracticeChordButton(chord: chord, category: category)
                        .environmentObject(practiceManager)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
    
    private func attemptColor(for index: Int) -> Color {
        if index < practiceManager.attempts.count {
            if let attempt = practiceManager.attempts[index] {
                return attempt == practiceManager.currentChord ? category.color : ColorTheme.error
            }
        } else if index == practiceManager.currentAttempt - 1 {
            return category.color.opacity(0.5)
        }
        return ColorTheme.textTertiary.opacity(0.3)
    }
}

// MARK: - Practice Chord Button
struct PracticeChordButton: View {
    let chord: ChordType
    let category: ChordCategory
    @EnvironmentObject var practiceManager: PracticeManager
    
    private var buttonColor: Color {
        if practiceManager.gameState == .answered {
            if chord == practiceManager.currentChord {
                return category.color
            } else if chord == practiceManager.selectedChord && chord != practiceManager.currentChord {
                return ColorTheme.error
            }
        } else if chord == practiceManager.selectedChord {
            return category.color.opacity(0.7)
        }
        return ColorTheme.secondaryBackground
    }
    
    var body: some View {
        Button(action: { selectChord() }) {
            Text(chord.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(buttonColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    practiceManager.gameState == .answered && chord == practiceManager.currentChord ?
                                    category.color.opacity(0.8) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
        }
        .disabled(practiceManager.gameState != .playing)
    }
    
    private func selectChord() {
        guard practiceManager.gameState == .playing else { return }
        practiceManager.submitGuess(chord)
    }
}

// MARK: - Specific Practice Views
struct BarreChordsPracticeView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        PracticeView(category: .barre)
            .environmentObject(audioManager)
    }
}

struct BluesChordsPracticeView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        PracticeView(category: .blues)
            .environmentObject(audioManager)
    }
}

struct PowerChordsPracticeView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        PracticeView(category: .power)
            .environmentObject(audioManager)
    }
}

// MARK: - Mixed Practice View (COMPLETE IMPLEMENTATION)
struct MixedPracticeView: View {
    @StateObject private var mixedManager = MixedPracticeManager()
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                
                if let currentCategory = mixedManager.currentCategory {
                    difficultyIndicator(currentCategory)
                }
                
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
                
                audioControlsSection
                gameStatusSection
                
                if mixedManager.gameState == .playing || mixedManager.gameState == .answered {
                    chordSelectionSection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Mixed Practice")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            mixedManager.startMixedPractice()
        }
        .onChange(of: mixedManager.currentAttempt) { _, _ in
            audioManager.resetForNewAttempt()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Question \(mixedManager.currentQuestion)/\(mixedManager.totalQuestions)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ColorTheme.primaryGreen)
                    
                    Text("Score: \(mixedManager.score)")
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
            
            ProgressView(value: Double(mixedManager.currentQuestion - 1), total: Double(mixedManager.totalQuestions))
                .progressViewStyle(LinearProgressViewStyle(tint: ColorTheme.primaryGreen))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
    
    private func difficultyIndicator(_ category: ChordCategory) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category.color)
                .frame(width: 12, height: 12)
            
            Text("Current: \(category.displayName)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textPrimary)
            
            Spacer()
            
            Text(mixedManager.currentChord?.difficultyLevel ?? "")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(category.color.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(category.color.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(category.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var audioControlsSection: some View {
        VStack(spacing: 12) {
            Text("Attempt \(mixedManager.currentAttempt) of \(mixedManager.maxAttempts)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTheme.primaryGreen)
            
            Button(action: playCurrentChord) {
                HStack(spacing: 12) {
                    Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" :
                          audioManager.isLoading ? "hourglass" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(audioManager.isLoading ? 360 : 0))
                        .animation(audioManager.isLoading ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default,
                                  value: audioManager.isLoading)
                    
                    Text(audioManager.isLoading ? "Loading..." :
                         audioManager.isPlaying ? "Playing..." :
                         audioManager.hasPlayedThisAttempt ? "Already Played" : "Play Mystery Chord")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(audioManager.isLoading || audioManager.hasPlayedThisAttempt ?
                              ColorTheme.textTertiary : ColorTheme.primaryGreen)
                )
            }
            .disabled(audioManager.isLoading || mixedManager.gameState != .playing || audioManager.hasPlayedThisAttempt)
        }
    }
    
    @ViewBuilder
    private var gameStatusSection: some View {
        switch mixedManager.gameState {
        case .playing:
            Text("Identify this mystery chord from any category!")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
    
    private var chordSelectionSection: some View {
        MixedChordSelectionView()
            .environmentObject(mixedManager)
    }
    
    private func playCurrentChord() {
        guard let chord = mixedManager.currentChord else { return }
        audioManager.playChord(chord, hintType: .chordNoFingers, audioOption: .chord)
    }
}

// MARK: - Mixed Practice Manager
class MixedPracticeManager: ObservableObject {
    @Published var currentQuestion = 1
    @Published var totalQuestions = 15
    @Published var score = 0
    @Published var currentChord: ChordType?
    @Published var selectedChord: ChordType?
    @Published var gameState: GameState = .waiting
    @Published var currentAttempt = 1
    @Published var maxAttempts = 4
    @Published var attempts: [ChordType?] = []
    @Published var jumbledFingerPositions: [Int] = []
    @Published var revealedFingerIndex: Int = -1
    @Published var currentCategory: ChordCategory?
    @Published var difficultyProgression: [ChordCategory] = []
    
    enum GameState {
        case waiting
        case playing
        case answered
        case completed
    }
    
    var difficultyMultiplier: Int {
        switch currentCategory {
        case .basic: return 1
        case .power: return 2
        case .barre: return 3
        case .blues: return 4
        default: return 1
        }
    }
    
    func startMixedPractice() {
        setupDifficultyProgression()
        currentQuestion = 1
        score = 0
        gameState = .waiting
        startNewQuestion()
    }
    
    private func setupDifficultyProgression() {
        difficultyProgression = [
            .basic, .basic, .basic,        // Questions 1-3: Basic
            .power, .power,               // Questions 4-5: Power chords
            .basic, .power,               // Questions 6-7: Mixed easy
            .barre, .barre,               // Questions 8-9: Barre chords
            .blues, .blues,               // Questions 10-11: Blues
            .basic, .barre,               // Questions 12-13: Mixed medium
            .blues, .power                // Questions 14-15: Final challenge
        ]
    }
    
    func startNewQuestion() {
        guard currentQuestion <= totalQuestions else {
            gameState = .completed
            return
        }
        
        let categoryIndex = min(currentQuestion - 1, difficultyProgression.count - 1)
        currentCategory = difficultyProgression[categoryIndex]
        
        let availableChords: [ChordType]
        switch currentCategory {
        case .basic: availableChords = ChordType.basicChords
        case .power: availableChords = ChordType.powerChords
        case .barre: availableChords = ChordType.barreChords
        case .blues: availableChords = ChordType.bluesChords
        default: availableChords = ChordType.basicChords
        }
        
        currentChord = availableChords.randomElement()
        selectedChord = nil
        currentAttempt = 1
        attempts = Array(repeating: nil, count: maxAttempts)
        gameState = .playing
        
        jumbledFingerPositions = []
        revealedFingerIndex = -1
    }
    
    func submitGuess(_ guess: ChordType) {
        guard gameState == .playing, currentAttempt <= maxAttempts else { return }
        
        selectedChord = guess
        attempts[currentAttempt - 1] = guess
        
        if guess == currentChord {
            let basePoints = difficultyMultiplier * 50
            let attemptPenalty = (currentAttempt - 1) * 15
            let points = max(basePoints - attemptPenalty, 15)
            score += points
            gameState = .answered
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.nextQuestion()
            }
        } else {
            currentAttempt += 1
            
            if currentAttempt == 3 && shouldProvideFingerHints() {
                generateJumbledFingerPositions()
            } else if currentAttempt == 4 && shouldProvideFingerHints() {
                revealRandomFingerPosition()
            }
            
            if currentAttempt > maxAttempts {
                gameState = .answered
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.nextQuestion()
                }
            }
        }
    }
    
    private func shouldProvideFingerHints() -> Bool {
        return currentCategory == .barre || currentCategory == .blues
    }
    
    func nextQuestion() {
        currentQuestion += 1
        startNewQuestion()
    }
    
    private func generateJumbledFingerPositions() {
        guard let chord = currentChord else { return }
        let correctPositions = chord.fingerPositions.map { $0.fret }
        jumbledFingerPositions = correctPositions.shuffled()
    }
    
    private func revealRandomFingerPosition() {
        guard let chord = currentChord else { return }
        let fingerPositions = chord.fingerPositions
        if !fingerPositions.isEmpty {
            revealedFingerIndex = Int.random(in: 0..<fingerPositions.count)
        }
    }
}

// MARK: - Mixed Chord Selection
// MARK: - Mixed Chord Selection
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
                    chordCategorySection(.basic, chords: ChordType.basicChords)
                    chordCategorySection(.power, chords: ChordType.powerChords)
                    chordCategorySection(.barre, chords: ChordType.barreChords)
                    chordCategorySection(.blues, chords: ChordType.bluesChords)
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
                        .stroke(ColorTheme.primaryGreen.opacity(0.3), lineWidth: 1)
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
                .fill(ColorTheme.primaryGreen)
                .frame(width: 50, height: 2)
                .cornerRadius(1)
        }
    }
    
    private func chordCategorySection(_ category: ChordCategory, chords: [ChordType]) -> some View {
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
                    MixedChordButton(chord: chord)
                        .environmentObject(mixedManager)
                }
            }
        }
    }
    
    private func attemptColor(for index: Int) -> Color {
        if index < mixedManager.attempts.count {
            if let attempt = mixedManager.attempts[index] {
                return attempt == mixedManager.currentChord ? ColorTheme.primaryGreen : ColorTheme.error
            }
        } else if index == mixedManager.currentAttempt - 1 {
            return ColorTheme.accentGreen
        }
        return ColorTheme.textTertiary.opacity(0.3)
    }
}

// MARK: - Mixed Chord Button
struct MixedChordButton: View {
    let chord: ChordType
    @EnvironmentObject var mixedManager: MixedPracticeManager
    
    private var buttonColor: Color {
        if mixedManager.gameState == .answered {
            if chord == mixedManager.currentChord {
                return chord.category.color
            } else if chord == mixedManager.selectedChord && chord != mixedManager.currentChord {
                return ColorTheme.error
            }
        } else if chord == mixedManager.selectedChord {
            return chord.category.color.opacity(0.7)
        }
        return ColorTheme.secondaryBackground
    }
    
    var body: some View {
        Button(action: { mixedManager.submitGuess(chord) }) {
            Text(chord.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    mixedManager.gameState == .answered && chord == mixedManager.currentChord ?
                                    chord.category.color.opacity(0.8) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                )
        }
        .disabled(mixedManager.gameState != .playing)
    }
}

// MARK: - Mixed Result Views
struct MixedResultView: View {
    @EnvironmentObject var mixedManager: MixedPracticeManager
    
    var body: some View {
        VStack(spacing: 16) {
            let isCorrect = mixedManager.selectedChord == mixedManager.currentChord
            let categoryColor = mixedManager.currentCategory?.color ?? ColorTheme.primaryGreen
            
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(isCorrect ? categoryColor : ColorTheme.error)
            
            Text(isCorrect ? "Correct!" : "Wrong!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isCorrect ? categoryColor : ColorTheme.error)
            
            if !isCorrect {
                VStack(spacing: 4) {
                    Text("Correct answer: \(mixedManager.currentChord?.displayName ?? "")")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    if let category = mixedManager.currentCategory {
                        Text("(\(category.displayName))")
                            .font(.system(size: 14))
                            .foregroundColor(category.color)
                    }
                }
            }
            
            if isCorrect {
                let basePoints = mixedManager.difficultyMultiplier * 50
                let attemptPenalty = (mixedManager.currentAttempt - 1) * 15
                let points = max(basePoints - attemptPenalty, 15)
                
                Text("+\(points) points")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(categoryColor.opacity(0.2))
                    )
                    .foregroundColor(categoryColor)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}

struct MixedCompletedView: View {
    @EnvironmentObject var mixedManager: MixedPracticeManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ColorTheme.primaryGreen)
            
            Text("Mixed Practice Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            VStack(spacing: 8) {
                Text("Final Score: \(mixedManager.score)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("Expert Level Mastery")
                    .font(.system(size: 16))
                    .foregroundColor(ColorTheme.primaryGreen)
            }
            
            HStack(spacing: 16) {
                Button("Play Again") {
                    mixedManager.startMixedPractice()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(color: ColorTheme.primaryGreen))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}
