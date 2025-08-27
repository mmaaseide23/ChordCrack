import SwiftUI

/// Speed round mode - quick chord identification under time pressure
struct SpeedRoundView: View {
    @StateObject private var speedManager = SpeedRoundManager()
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                timerSection
                guitarNeckSection
                audioControlsSection
                gameStatusSection
                
                if speedManager.gameState == .playing {
                    speedChordSelectionSection
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Speed Round")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            speedManager.startSpeedRound()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Round \(speedManager.currentRound)/\(speedManager.totalRounds)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.red)
                    
                    Text("Score: \(speedManager.score)")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                
                Spacer()
                
                Button("End Round") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.system(size: 13))
                .foregroundColor(ColorTheme.textSecondary)
            }
            
            ProgressView(value: Double(speedManager.currentRound - 1), total: Double(speedManager.totalRounds))
                .progressViewStyle(LinearProgressViewStyle(tint: Color.red))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
    
    private var timerSection: some View {
        VStack(spacing: 8) {
            Text("Time Remaining")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
            
            Text(speedManager.formattedTimeRemaining)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(speedManager.timeRemaining <= 5 ? Color.red : Color.orange)
            
            Rectangle()
                .fill(speedManager.timeRemaining <= 5 ? Color.red : Color.orange)
                .frame(height: 4)
                .frame(width: CGFloat(speedManager.timeRemaining) / CGFloat(speedManager.timeLimit) * 200)
                .animation(.linear(duration: 0.1), value: speedManager.timeRemaining)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(speedManager.timeRemaining <= 5 ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }
    
    private var guitarNeckSection: some View {
        GuitarNeckView(
            chord: speedManager.currentChord,
            currentAttempt: 1, // No hints in speed mode
            jumbledPositions: [],
            revealedFingerIndex: -1
        )
        .onChange(of: audioManager.isPlaying) { _, newValue in
            if newValue {
                NotificationCenter.default.post(name: .triggerStringShake, object: nil)
            }
        }
    }
    
    private var audioControlsSection: some View {
        VStack(spacing: 12) {
            Text("Listen quickly!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.red)
            
            Button(action: playCurrentChord) {
                HStack(spacing: 12) {
                    Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" :
                          speedManager.hasPlayedCurrentChord ? "checkmark.circle" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(audioManager.isPlaying ? "Playing..." :
                         speedManager.hasPlayedCurrentChord ? "Played" : "Play Chord")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(speedManager.hasPlayedCurrentChord ? ColorTheme.primaryGreen : Color.red)
                )
            }
            .disabled(speedManager.gameState != .playing)
        }
    }
    
    @ViewBuilder
    private var gameStatusSection: some View {
        switch speedManager.gameState {
        case .playing:
            Text("Quick! What chord is this?")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
        case .timeUp:
            Text("Time's Up!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.red)
        case .completed:
            SpeedRoundCompletedView()
                .environmentObject(speedManager)
        default:
            EmptyView()
        }
    }
    
    private var speedChordSelectionSection: some View {
        SpeedChordSelectionView()
            .environmentObject(speedManager)
    }
    
    private func playCurrentChord() {
        guard let chord = speedManager.currentChord else { return }
        speedManager.markChordAsPlayed()
        audioManager.playChord(chord, hintType: .chordNoFingers, audioOption: .chord)
    }
}

// MARK: - Speed Round Manager

class SpeedRoundManager: ObservableObject {
    @Published var currentRound = 1
    @Published var totalRounds = 20
    @Published var score = 0
    @Published var currentChord: ChordType?
    @Published var selectedChord: ChordType?
    @Published var gameState: GameState = .waiting
    @Published var timeRemaining: Double = 15.0
    @Published var hasPlayedCurrentChord = false
    
    let timeLimit: Double = 15.0
    private var timer: Timer?
    
    enum GameState {
        case waiting
        case playing
        case timeUp
        case completed
    }
    
    var formattedTimeRemaining: String {
        String(format: "%.1f", timeRemaining)
    }
    
    func startSpeedRound() {
        currentRound = 1
        score = 0
        gameState = .waiting
        startNewRound()
    }
    
    func startNewRound() {
        guard currentRound <= totalRounds else {
            gameState = .completed
            stopTimer()
            return
        }
        
        // Use all chord types for speed challenge
        currentChord = ChordType.allCases.randomElement()
        selectedChord = nil
        hasPlayedCurrentChord = false
        timeRemaining = timeLimit
        gameState = .playing
        
        startTimer()
    }
    
    func submitGuess(_ guess: ChordType) {
        guard gameState == .playing else { return }
        
        selectedChord = guess
        stopTimer()
        
        if guess == currentChord {
            // Bonus points for faster answers
            let timeBonus = Int(timeRemaining * 10)
            score += 100 + timeBonus
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.nextRound()
        }
    }
    
    func nextRound() {
        currentRound += 1
        startNewRound()
    }
    
    func markChordAsPlayed() {
        hasPlayedCurrentChord = true
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.timeRemaining -= 0.1
                
                if self.timeRemaining <= 0 {
                    self.timeUp()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timeUp() {
        stopTimer()
        gameState = .timeUp
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.nextRound()
        }
    }
    
    deinit {
        stopTimer()
    }
}

// MARK: - Speed Chord Selection

struct SpeedChordSelectionView: View {
    @EnvironmentObject var speedManager: SpeedRoundManager
    
    private let quickChords: [ChordType] = [
        .cMajor, .dMajor, .eMajor, .fMajor, .gMajor, .aMajor,
        .cMinor, .dMinor, .eMinor, .fMinor, .gMinor, .aMinor,
        .c7, .d7, .e7, .g7, .a7,
        .e5, .a5, .d5, .g5
    ]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Tap quickly!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.red)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(quickChords) { chord in
                    Button(action: {
                        speedManager.submitGuess(chord)
                    }) {
                        Text(chord.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(height: 32)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ColorTheme.secondaryBackground)
                            )
                    }
                    .disabled(speedManager.gameState != .playing)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct SpeedRoundCompletedView: View {
    @EnvironmentObject var speedManager: SpeedRoundManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "timer")
                .font(.system(size: 60))
                .foregroundColor(Color.red)
            
            Text("Speed Round Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            VStack(spacing: 8) {
                Text("Final Score: \(speedManager.score)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("Lightning Fast Recognition")
                    .font(.system(size: 16))
                    .foregroundColor(Color.red)
            }
            
            HStack(spacing: 16) {
                Button("Play Again") {
                    speedManager.startSpeedRound()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(color: Color.red))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}

// MARK: - Enhanced Achievement System

extension Achievement {
    
    var xpReward: Int {
        switch self {
        case .firstSteps: return 50
        case .streakMaster: return 100
        case .perfectRound: return 150
        case .barreExpert: return 200
        case .bluesScholar: return 200
        case .powerPlayer: return 150
        case .chordWizard: return 300
        case .perfectPitch: return 500
        case .speedDemon: return 250
        }
    }
    
    var rarity: AchievementRarity {
        switch self {
        case .firstSteps, .streakMaster: return .common
        case .perfectRound, .powerPlayer, .barreExpert: return .rare
        case .bluesScholar, .speedDemon: return .epic
        case .chordWizard, .perfectPitch: return .legendary
        }
    }
}

enum AchievementRarity {
    case common, rare, epic, legendary
    
    var color: Color {
        switch self {
        case .common: return Color.gray
        case .rare: return Color.blue
        case .epic: return Color.purple
        case .legendary: return Color.orange
        }
    }
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
}

// MARK: - Seasonal Events

struct SeasonalEventBanner: View {
    let event: SeasonalEvent
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: event.icon)
                .font(.system(size: 24))
                .foregroundColor(event.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text(event.description)
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
                
                Text("Ends in \(event.timeRemaining)")
                    .font(.system(size: 10))
                    .foregroundColor(event.color)
            }
            
            Spacer()
            
            Button("Join") {
                // Handle event participation
            }
            .buttonStyle(PrimaryButtonStyle(color: event.color))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(event.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(event.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct SeasonalEvent {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let timeRemaining: String
    let isActive: Bool
    
    static let currentEvents = [
        SeasonalEvent(
            title: "Holiday Harmonies",
            description: "Special holiday chord challenges with festive rewards!",
            icon: "gift.fill",
            color: Color.red,
            timeRemaining: "5 days",
            isActive: true
        ),
        SeasonalEvent(
            title: "New Year Resolution",
            description: "Play every day in January for exclusive badge!",
            icon: "calendar",
            color: ColorTheme.primaryGreen,
            timeRemaining: "12 days",
            isActive: true
        )
    ]
}

// MARK: - Notification System

class NotificationManager: ObservableObject {
    @Published var notifications: [AppNotification] = []
    
    func addNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        
        // Auto-remove after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.removeNotification(notification)
        }
    }
    
    private func removeNotification(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
}

struct AppNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let createdAt = Date()
    
    enum NotificationType {
        case achievement
        case challenge
        case reward
        case friend
        
        var color: Color {
            switch self {
            case .achievement: return ColorTheme.primaryGreen
            case .challenge: return Color.orange
            case .reward: return Color.yellow
            case .friend: return Color.blue
            }
        }
        
        var icon: String {
            switch self {
            case .achievement: return "trophy.fill"
            case .challenge: return "person.2.fill"
            case .reward: return "gift.fill"
            case .friend: return "person.badge.plus"
            }
        }
    }
}
