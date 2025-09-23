import SwiftUI

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var userDataManager = UserDataManager()
    @StateObject private var themeManager = ThemeManager()
    @State private var showTutorial = false
    
    var body: some View {
        NavigationView {
            if !userDataManager.isUsernameSet {
                UsernameSetupView()
                    .environmentObject(userDataManager)
                    .environmentObject(themeManager)
            } else {
                EnhancedHomeView()
                    .environmentObject(gameManager)
                    .environmentObject(audioManager)
                    .environmentObject(userDataManager)
                    .environmentObject(themeManager)
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .onAppear {
            setupInitialState()
        }
        .onChange(of: userDataManager.isUsernameSet) { oldValue, newValue in
            if !oldValue && newValue && userDataManager.isNewUser && !userDataManager.hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTutorial = true
                }
            }
        }
        .onChange(of: userDataManager.hasSeenTutorial) { oldValue, newValue in
            if oldValue && !newValue && userDataManager.isUsernameSet {
                showTutorial = true
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            WelcomeTutorialView(showTutorial: $showTutorial)
                .onDisappear {
                    if !userDataManager.hasSeenTutorial {
                        userDataManager.completeTutorial()
                    }
                }
        }
    }
    
    private func setupInitialState() {
        gameManager.setUserDataManager(userDataManager)
        gameManager.setAudioManager(audioManager)
        userDataManager.checkAuthenticationStatus()
    }
}

// MARK: - Enhanced Home View with Reverse Mode Toggle

struct EnhancedHomeView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentDate = Date()
    @State private var showingStats = false
    @State private var isAnimatingToggle = false
    
    var body: some View {
        ZStack {
            // Dynamic background based on mode
            ColorTheme.dynamicBackground(isReversed: userDataManager.reverseModeEnabled)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: userDataManager.reverseModeEnabled)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerWithToggle
                    
                    if userDataManager.reverseModeEnabled {
                        reverseModeChallengeCard
                        reverseModeStatsCard
                        reverseModePracticeSection
                        reverseModeAchievementsSection
                    } else {
                        dailyChallengeCard
                        quickStatsCard
                        practiceModesSection
                        achievementsPreviewSection
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            currentDate = Date()
        }
    }
    
    // MARK: - Header with Reverse Mode Toggle
    
    private var headerWithToggle: some View {
        VStack(spacing: 20) {
            // Original header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    ChordCrackLogo(
                        size: .medium,
                        style: .withText
                    )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome back, \(userDataManager.username)!")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        if userDataManager.reverseModeEnabled {
                            Text("Build chords from memory!")
                                .font(.system(size: 14))
                                .foregroundColor(ColorTheme.primaryPurple)
                        } else if userDataManager.totalGamesPlayed == 0 {
                            Text("Start with your first Daily Challenge!")
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
                        NavigationLink(destination: SocialFeaturesView()
                            .environmentObject(userDataManager)) {
                            Circle()
                                .fill(ColorTheme.dynamicCardBackground(isReversed: userDataManager.reverseModeEnabled))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(ColorTheme.dynamicPrimary(isReversed: userDataManager.reverseModeEnabled))
                                )
                        }
                        
                        NavigationLink(destination: ProfileView()
                            .environmentObject(userDataManager)
                            .environmentObject(gameManager)) {
                            Circle()
                                .fill(ColorTheme.dynamicPrimary(isReversed: userDataManager.reverseModeEnabled))
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
            
            // Reverse Mode Toggle
            reverseModeToggle
        }
        .padding(.top, 20)
    }
    
    // MARK: - Reverse Mode Toggle
    
    private var reverseModeToggle: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Listen Mode
                VStack(spacing: 4) {
                    Image(systemName: "ear")
                        .font(.system(size: 20))
                        .foregroundColor(!userDataManager.reverseModeEnabled ? ColorTheme.primaryGreen : ColorTheme.textTertiary)
                    
                    Text("Listen")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(!userDataManager.reverseModeEnabled ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                }
                .frame(width: 60)
                
                // Toggle Switch
                Toggle("", isOn: $userDataManager.reverseModeEnabled)
                    .toggleStyle(ReverseModeToggleStyle())
                    .scaleEffect(1.2)
                    .onChange(of: userDataManager.reverseModeEnabled) { _, newValue in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isAnimatingToggle = true
                        }
                        
                        // Haptic feedback
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isAnimatingToggle = false
                        }
                    }
                
                // Build Mode
                VStack(spacing: 4) {
                    Image(systemName: "hand.point.up")
                        .font(.system(size: 20))
                        .foregroundColor(userDataManager.reverseModeEnabled ? ColorTheme.primaryPurple : ColorTheme.textTertiary)
                    
                    Text("Build")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(userDataManager.reverseModeEnabled ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                }
                .frame(width: 60)
            }
            
            Text(userDataManager.reverseModeEnabled ? "Reverse Mode: Build chords on the fretboard" : "Normal Mode: Identify chords by ear")
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.dynamicCardBackground(isReversed: userDataManager.reverseModeEnabled).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ColorTheme.dynamicPrimary(isReversed: userDataManager.reverseModeEnabled).opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .scaleEffect(isAnimatingToggle ? 1.05 : 1.0)
    }
    
    // MARK: - Normal Mode Daily Challenge Card
    
    private var dailyChallengeCard: some View {
        NavigationLink(destination: GameView()
            .environmentObject(gameManager)
            .environmentObject(audioManager)
            .environmentObject(userDataManager)) {
            VStack(spacing: 20) {
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
                        
                        Text(DateFormatter.dailyFormat.string(from: currentDate))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    Spacer()
                    
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
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("5 quick rounds")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(ColorTheme.primaryGreen)
                                
                                Text("Basic chords only")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ColorTheme.textSecondary)
                            }
                            
                            Text("Perfect for daily ear training")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        
                        Spacer()
                        
                        if gameManager.streak > 0 {
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
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Level \(userDataManager.currentLevel)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.primaryGreen)
                            
                            Spacer()
                            
                            let xpInCurrentLevel = userDataManager.currentXP % 1000
                            Text("\(max(0, xpInCurrentLevel))/1000 XP")
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
                                        width: max(0, geometry.size.width * userDataManager.levelProgress),
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
    
    // MARK: - Normal Mode Quick Stats Card
    
    private var quickStatsCard: some View {
        VStack(spacing: 12) {
            Text("Your Progress Today")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
            
            HStack(spacing: 16) {
                QuickStatItem(
                    icon: "gamecontroller.fill",
                    value: "\(userDataManager.totalGamesPlayed)",
                    label: "Total Games",
                    color: Color.blue
                )
                
                Rectangle()
                    .fill(ColorTheme.textTertiary.opacity(0.2))
                    .frame(width: 1, height: 30)
                
                QuickStatItem(
                    icon: "target",
                    value: String(format: "%.0f%%", userDataManager.overallAccuracy),
                    label: "Accuracy",
                    color: ColorTheme.primaryGreen
                )
                
                Rectangle()
                    .fill(ColorTheme.textTertiary.opacity(0.2))
                    .frame(width: 1, height: 30)
                
                QuickStatItem(
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
            StatsView()
                .environmentObject(userDataManager)
                .environmentObject(gameManager)
        }
    }
    
    // MARK: - Normal Mode Practice Modes Section
    
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
                    PracticeModeCard(
                        title: "Power Chords",
                        description: "Rock fundamentals",
                        icon: "bolt.circle.fill",
                        color: Color.red,
                        difficulty: "Easy",
                        progress: userDataManager.categoryAccuracy(for: GameTypeConstants.powerChords) / 100.0,
                        destination: AnyView(PowerChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                    )
                    
                    PracticeModeCard(
                        title: "Barre Chords",
                        description: "Advanced patterns",
                        icon: "guitars.fill",
                        color: Color.orange,
                        difficulty: "Hard",
                        progress: userDataManager.categoryAccuracy(for: GameTypeConstants.barreChords) / 100.0,
                        destination: AnyView(BarreChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                    )
                    
                    PracticeModeCard(
                        title: "Blues Chords",
                        description: "7th & extensions",
                        icon: "music.quarternote.3",
                        color: Color.blue,
                        difficulty: "Expert",
                        progress: userDataManager.categoryAccuracy(for: GameTypeConstants.bluesChords) / 100.0,
                        destination: AnyView(BluesChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                    )
                    
                    PracticeModeCard(
                        title: "Mixed Mode",
                        description: "All chord types",
                        icon: "shuffle.circle.fill",
                        color: Color.purple,
                        difficulty: "Master",
                        progress: userDataManager.categoryAccuracy(for: GameTypeConstants.mixedPractice) / 100.0,
                        destination: AnyView(MixedPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                    )
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Normal Mode Achievements Preview Section

    private var achievementsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Text("Keep practicing!")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.primaryGreen)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Use HomeAchievementBadge with proper syntax
                    HomeAchievementBadge(
                        title: "First Steps",
                        icon: "star.fill",
                        isUnlocked: userDataManager.totalGamesPlayed > 0,
                        color: Color.yellow
                    )
                    
                    HomeAchievementBadge(
                        title: "Streak Master",
                        icon: "flame.fill",
                        isUnlocked: userDataManager.bestStreak >= 7,
                        color: Color.orange
                    )
                    
                    HomeAchievementBadge(
                        title: "Power Player",
                        icon: "bolt.fill",
                        isUnlocked: userDataManager.categoryAccuracy(for: GameTypeConstants.powerChords) >= 80,
                        color: Color.red
                    )
                    
                    HomeAchievementBadge(
                        title: "Perfect Round",
                        icon: "checkmark.seal.fill",
                        isUnlocked: userDataManager.perfectRounds > 0,
                        color: ColorTheme.primaryGreen
                    )
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Reverse Mode Challenge Card
    
    private var reverseModeChallengeCard: some View {
        NavigationLink(destination: ReverseModeView(gameMode: .dailyChallenge)
            .environmentObject(audioManager)
            .environmentObject(userDataManager)
            .environmentObject(themeManager)) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.point.up.fill")
                                .foregroundColor(ColorTheme.primaryPurple)
                                .font(.system(size: 16))
                            
                            Text("Reverse Daily Challenge")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(ColorTheme.textPrimary)
                        }
                        
                        Text(DateFormatter.dailyFormat.string(from: currentDate))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(ColorTheme.primaryPurple)
                            .frame(width: 56, height: 56)
                        
                        Circle()
                            .stroke(ColorTheme.lightPurple.opacity(0.3), lineWidth: 2)
                            .frame(width: 62, height: 62)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }
                }
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("Build 10 chords")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(ColorTheme.primaryPurple)
                                
                                Text("Place fingers correctly")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ColorTheme.textSecondary)
                            }
                            
                            Text("Test your fretboard knowledge")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        
                        Spacer()
                        
                        if userDataManager.reverseModeLevel > 0 {
                            VStack(alignment: .trailing, spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(ColorTheme.brightPurple)
                                        .font(.system(size: 16))
                                    
                                    Text("Lvl \(userDataManager.reverseModeLevel)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(ColorTheme.brightPurple)
                                }
                                
                                Text("Reverse Mode")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(ColorTheme.textTertiary)
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Level \(userDataManager.reverseModeLevel)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.primaryPurple)
                            
                            Spacer()
                            
                            let xpInCurrentLevel = userDataManager.reverseModeTotalXP % 1000
                            Text("\(max(0, xpInCurrentLevel))/1000 XP")
                                .font(.system(size: 10))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ColorTheme.reverseSecondaryBackground)
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [ColorTheme.primaryPurple, ColorTheme.lightPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(
                                        width: max(0, geometry.size.width * userDataManager.reverseModeLevelProgress),
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
                    .fill(ColorTheme.reverseCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(ColorTheme.primaryPurple.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 24)
    }
    
    // MARK: - Reverse Mode Stats Card
    
    private var reverseModeStatsCard: some View {
        VStack(spacing: 12) {
            Text("Reverse Mode Progress")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
            
            HStack(spacing: 16) {
                QuickStatItem(
                    icon: "hand.point.up.fill",
                    value: "\(userDataManager.reverseModeTotalGames)",
                    label: "Built",
                    color: ColorTheme.primaryPurple
                )
                
                Rectangle()
                    .fill(ColorTheme.textTertiary.opacity(0.2))
                    .frame(width: 1, height: 30)
                
                QuickStatItem(
                    icon: "target",
                    value: String(format: "%.0f%%", userDataManager.reverseModeAccuracy),
                    label: "Accuracy",
                    color: ColorTheme.brightPurple
                )
                
                Rectangle()
                    .fill(ColorTheme.textTertiary.opacity(0.2))
                    .frame(width: 1, height: 30)
                
                QuickStatItem(
                    icon: "trophy.fill",
                    value: "\(userDataManager.reverseModeBestScore)",
                    label: "Best",
                    color: ColorTheme.accentPurple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.reverseCardBackground.opacity(0.8))
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - Reverse Mode Practice Section
    
    private var reverseModePracticeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reverse Practice Modes")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("Build chords from memory")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ReverseModePracticeCard(
                        title: "Power Chords",
                        description: "Simple shapes",
                        icon: "bolt.circle.fill",
                        color: ColorTheme.reverseAccent,
                        difficulty: "Easy",
                        progress: userDataManager.reverseModeCategoryStats["reversePowerChords"]?.accuracy ?? 0 / 100.0,
                        category: .power
                    )
                    
                    ReverseModePracticeCard(
                        title: "Barre Chords",
                        description: "Complex patterns",
                        icon: "guitars.fill",
                        color: ColorTheme.primaryPurple,
                        difficulty: "Hard",
                        progress: userDataManager.reverseModeCategoryStats["reverseBarreChords"]?.accuracy ?? 0 / 100.0,
                        category: .barre
                    )
                    
                    ReverseModePracticeCard(
                        title: "Blues Chords",
                        description: "7th positions",
                        icon: "music.quarternote.3",
                        color: ColorTheme.lightPurple,
                        difficulty: "Expert",
                        progress: userDataManager.reverseModeCategoryStats["reverseBluesChords"]?.accuracy ?? 0 / 100.0,
                        category: .blues
                    )
                    
                    ReverseModePracticeCard(
                        title: "Mixed Mode",
                        description: "All types",
                        icon: "shuffle.circle.fill",
                        color: ColorTheme.brightPurple,
                        difficulty: "Master",
                        progress: userDataManager.reverseModeCategoryStats["reverseMixedPractice"]?.accuracy ?? 0 / 100.0,
                        category: nil
                    )
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Reverse Mode Achievements Section
    
    private var reverseModeAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reverse Achievements")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Text("\(userDataManager.reverseModeAchievements.count)/10")
                    .font(.system(size: 14))
                    .foregroundColor(ColorTheme.primaryPurple)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([ReverseModeAchievement.reverseFirstSteps,
                            ReverseModeAchievement.reverseStreakMaster,
                            ReverseModeAchievement.reverseNoHints,
                            ReverseModeAchievement.reverseLevel10], id: \.rawValue) { achievement in
                        ReverseAchievementBadge(
                            achievement: achievement,
                            isUnlocked: userDataManager.reverseModeAchievements.contains(achievement)
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Components

struct QuickStatItem: View {
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

struct PracticeModeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let difficulty: String
    let progress: Double
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 0) {
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

// Simple Achievement Badge that doesn't rely on Achievement enum
struct SimpleAchievementBadge: View {
    let title: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : ColorTheme.textTertiary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isUnlocked ? color : ColorTheme.textTertiary.opacity(0.5))
                
                if isUnlocked {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 70)
    }
}

struct ReverseAchievementBadge: View {
    let achievement: ReverseModeAchievement
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

struct ReverseModePracticeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let difficulty: String
    let progress: Double
    let category: ChordCategory?
    
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            VStack(spacing: 0) {
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
                                .fill(ColorTheme.reverseSecondaryBackground)
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
                    .fill(ColorTheme.reverseCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var destinationView: some View {
        if let category = category {
            ReverseModeView(gameMode: gameModeForCategory(category), practiceCategory: category)
                .environmentObject(audioManager)
                .environmentObject(userDataManager)
                .environmentObject(themeManager)
        } else {
            ReverseModeView(gameMode: .mixedPractice)
                .environmentObject(audioManager)
                .environmentObject(userDataManager)
                .environmentObject(themeManager)
        }
    }
    
    private func gameModeForCategory(_ category: ChordCategory) -> GameType {
        switch category {
        case .basic: return .basicPractice
        case .power: return .powerPractice
        case .barre: return .barrePractice
        case .blues: return .bluesPractice
        }
    }
}

// MARK: - Custom Toggle Style

struct ReverseModeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? ColorTheme.primaryPurple : ColorTheme.primaryGreen)
                .frame(width: 51, height: 31)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .padding(3)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let dailyFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter
    }()
}

#Preview {
    ContentView()
}
