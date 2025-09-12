import SwiftUI

/// Main application entry point with authentication support
struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var userDataManager = UserDataManager()
    @State private var showTutorial = false
    
    var body: some View {
        NavigationView {
            if !userDataManager.isUsernameSet {
                UsernameSetupView()
                    .environmentObject(userDataManager)
            } else {
                HomeView()
                    .environmentObject(gameManager)
                    .environmentObject(audioManager)
                    .environmentObject(userDataManager)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupInitialState()
        }
        .onChange(of: userDataManager.isUsernameSet) { _, isSet in
            // Show tutorial only for new users who haven't seen it yet
            if isSet && userDataManager.isNewUser && !userDataManager.hasSeenTutorial {
                showTutorial = true
            }
        }
        .onChange(of: userDataManager.hasSeenTutorial) { _, hasSeen in
            // Show tutorial when hasSeenTutorial becomes false (reset tutorial button)
            if !hasSeen && userDataManager.isUsernameSet {
                showTutorial = true
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            WelcomeTutorialView(showTutorial: $showTutorial)
                .onDisappear {
                    userDataManager.completeTutorial()
                }
        }
    }
    
    private func setupInitialState() {
        gameManager.setUserDataManager(userDataManager)
        gameManager.setAudioManager(audioManager)
        
        // Check if user is already authenticated
        userDataManager.checkAuthenticationStatus()
    }
}

// MARK: - Enhanced Home View with Fixed Layout

/// Enhanced home screen with professional gamification and fixed layout
struct HomeView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @State private var currentDate = Date()
    @State private var showingStats = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                headerSection
                dailyChallengeCard
                quickStatsCard
                practiceModesSection
                achievementsPreviewSection
                
                Spacer(minLength: 40)
            }
        }
        .navigationBarHidden(true)
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            currentDate = Date()
        }
    }
    
    // MARK: - Fixed Header Section - Removed Logo Click Functionality
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                // Logo with no tap gesture
                ChordCrackLogo(size: .medium, style: .withText)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back, \(userDataManager.username)!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    // Helpful guidance text
                    if userDataManager.totalGamesPlayed == 0 {
                        Text("Start with your first Daily Challenge below!")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.primaryGreen)
                    } else {
                        Text("Keep building that streak!")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.accentGreen)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Social features - seamless style
                    NavigationLink(destination: SocialFeaturesView()
                        .environmentObject(userDataManager)) {
                        Circle()
                            .fill(ColorTheme.cardBackground)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(ColorTheme.primaryGreen)
                            )
                    }
                    
                    // Profile avatar
                    NavigationLink(destination: ProfileView()
                        .environmentObject(userDataManager)
                        .environmentObject(gameManager)) {
                        Circle()
                            .fill(ColorTheme.primaryGreen)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(userDataManager.username.prefix(1)).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Enhanced Daily Challenge Card with Seamless Styling
    
    private var dailyChallengeCard: some View {
        NavigationLink(destination: HomePageDailyPuzzleView()
            .environmentObject(gameManager)
            .environmentObject(audioManager)
            .environmentObject(userDataManager)) {
            VStack(spacing: 20) {
                // Header with animated play button
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(ColorTheme.primaryGreen)
                                .font(.system(size: 16))
                            
                            Text("Daily Challenge")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(ColorTheme.textPrimary)
                        }
                        
                        Text(HomePageDateFormatter.dailyFormat.string(from: currentDate))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Animated play button
                    ZStack {
                        Circle()
                            .fill(ColorTheme.primaryGreen)
                            .frame(width: 56, height: 56)
                        
                        Circle()
                            .stroke(ColorTheme.lightGreen.opacity(0.3), lineWidth: 2)
                            .frame(width: 62, height: 62)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }
                }
                
                // Challenge details with progress
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("5 quick rounds")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(ColorTheme.primaryGreen)
                                
                                Text("• Basic chords only")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ColorTheme.textSecondary)
                            }
                            
                            Text("Perfect for daily ear training")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        
                        Spacer()
                        
                        // Streak display with flame animation
                        if gameManager.totalGames > 0 {
                            VStack(alignment: .trailing, spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(Color.orange)
                                        .font(.system(size: 16))
                                    
                                    Text("\(gameManager.streak)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color.orange)
                                }
                                
                                Text("Current Streak")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(ColorTheme.textTertiary)
                            }
                        }
                    }
                    
                    // XP Progress bar (simplified)
                    VStack(spacing: 8) {
                        HStack {
                            Text("Level \(userDataManager.currentLevel)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.primaryGreen)
                            
                            Spacer()
                            
                            let currentLevelXP = userDataManager.currentXP - userDataManager.currentLevel * 1000
                            Text("\(currentLevelXP)/1000 XP")
                                .font(.system(size: 10))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ColorTheme.secondaryBackground)
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [ColorTheme.primaryGreen, ColorTheme.lightGreen],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(
                                        width: geometry.size.width * userDataManager.levelProgress,
                                        height: 6
                                    )
                            }
                        }
                        .frame(height: 6)
                    }
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
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 24)
    }
    
    // MARK: - Quick Stats Card with Seamless Styling
    
    private var quickStatsCard: some View {
        VStack(spacing: 12) {
            Text("Your Progress Today")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
            
            HStack(spacing: 16) {
                HomeQuickStatItem(
                    icon: "gamecontroller.fill",
                    value: "\(userDataManager.totalGamesPlayed)",
                    label: "Total Games",
                    color: Color.blue
                )
                
                Rectangle()
                    .fill(ColorTheme.textTertiary.opacity(0.2))
                    .frame(width: 1, height: 30)
                
                HomeQuickStatItem(
                    icon: "target",
                    value: String(format: "%.0f%%", userDataManager.overallAccuracy),
                    label: "Accuracy",
                    color: ColorTheme.primaryGreen
                )
                
                Rectangle()
                    .fill(ColorTheme.textTertiary.opacity(0.2))
                    .frame(width: 1, height: 30)
                
                HomeQuickStatItem(
                    icon: "crown.fill",
                    value: "\(userDataManager.bestStreak)",
                    label: "Best Streak",
                    color: Color.orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground.opacity(0.8))
        )
        .padding(.horizontal, 24)
        .onTapGesture {
            showingStats = true
        }
        .sheet(isPresented: $showingStats) {
            HomeStatsDetailView()
                .environmentObject(userDataManager)
                .environmentObject(gameManager)
        }
    }
    
    // MARK: - Enhanced Practice Modes Section - Only Core Modes
        
        private var practiceModesSection: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Practice Modes")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                        
                        Text("Choose your skill level")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        HomePracticeModeCard(
                            title: "Power Chords",
                            description: "Rock fundamentals",
                            icon: "bolt.circle.fill",
                            color: Color.red,  // Changed from orange to red to match GameType.powerPractice
                            difficulty: "Easy",
                            progress: userDataManager.categoryAccuracy(for: GameTypeConstants.powerChords) / 100.0,
                            destination: AnyView(PowerChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                        )
                        
                        HomePracticeModeCard(
                            title: "Barre Chords",
                            description: "Advanced patterns",
                            icon: "guitars.fill",
                            color: Color.orange,  // Changed from purple to orange to match GameType.barrePractice
                            difficulty: "Hard",
                            progress: userDataManager.categoryAccuracy(for: GameTypeConstants.barreChords) / 100.0,
                            destination: AnyView(BarreChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                        )
                        
                        HomePracticeModeCard(
                            title: "Blues Chords",
                            description: "7th & extensions",
                            icon: "music.quarternote.3",
                            color: Color.blue,  // Stays blue - matches GameType.bluesPractice
                            difficulty: "Expert",
                            progress: userDataManager.categoryAccuracy(for: GameTypeConstants.bluesChords) / 100.0,
                            destination: AnyView(BluesChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                        )
                        
                        HomePracticeModeCard(
                            title: "Mixed Mode",
                            description: "All chord types",
                            icon: "shuffle.circle.fill",
                            color: Color.purple,  // Changed from primaryGreen to purple to match GameType.mixedPractice
                            difficulty: "Master",
                            progress: userDataManager.categoryAccuracy(for: GameTypeConstants.mixedPractice) / 100.0,
                            destination: AnyView(MixedPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                        )
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    
    // MARK: - Achievements Preview Section - Simplified
    
    private var achievementsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                // Simple text instead of navigation
                Text("Keep practicing!")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.primaryGreen)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([Achievement.firstSteps, Achievement.streakMaster, Achievement.powerPlayer, Achievement.perfectRound], id: \.rawValue) { achievement in
                        HomeAchievementBadge(
                            achievement: achievement,
                            isUnlocked: userDataManager.achievements.contains(achievement)
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Home-Specific Supporting Views (Unique Names to Avoid Conflicts)

struct HomeQuickStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textSecondary)
        }
    }
}

struct HomePracticeModeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let difficulty: String
    let progress: Double  // Now uses real progress data
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 0) {
                // Header with icon and difficulty
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(color)
                    }
                    
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Text(difficulty)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.15))
                        )
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Progress section - NOW USES REAL DATA
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)
                        
                        Spacer()
                        
                        Text("\(Int(max(progress, 0.0) * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorTheme.secondaryBackground)
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(
                                    width: geometry.size.width * max(progress, 0.0),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(width: 140, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HomeAchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievement.color.opacity(0.2) : ColorTheme.textTertiary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isUnlocked ? achievement.color : ColorTheme.textTertiary.opacity(0.5))
                
                if isUnlocked {
                    Circle()
                        .stroke(achievement.color, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            
            Text(achievement.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 70)
    }
}

struct HomeStatsDetailView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Text("Overall Statistics")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            StatCard(title: "Games Played", value: "\(userDataManager.totalGamesPlayed)")
                            StatCard(title: "Best Score", value: "\(userDataManager.bestScore)")
                            StatCard(title: "Best Streak", value: "\(userDataManager.bestStreak)")
                            StatCard(title: "Accuracy", value: String(format: "%.1f%%", userDataManager.overallAccuracy))
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(ColorTheme.background)
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// MARK: - Daily Puzzle View (Home-Specific)

/// Daily challenge game view - uses the compact GameView
struct HomePageDailyPuzzleView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    
    var body: some View {
        GameView()
            .environmentObject(gameManager)
            .environmentObject(audioManager)
            .environmentObject(userDataManager)
    }
}

// MARK: - Extensions (Home-Specific)

extension HomePageDateFormatter {
    static let dailyFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter
    }()
}

struct HomePageDateFormatter {
    // Empty struct to namespace the DateFormatter
}

#Preview {
    ContentView()
}
