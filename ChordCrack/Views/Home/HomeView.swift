import SwiftUI

struct HomeView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var currentDate = Date()
    @State private var showingStats = false
    private let analytics = FirebaseAnalyticsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                dailyChallengeCard
                quickStatsCard
                practiceModesSection
                achievementsSection
            }
            .padding(.top, 20).padding(.bottom, 40)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .clipped()
        .toolbar(.hidden, for: .navigationBar)
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            currentDate = Date()
            analytics.trackScreenView("home")
        }
        .sheet(isPresented: $showingStats) {
            HomeStatsDetailView().environmentObject(userDataManager).environmentObject(gameManager)
        }
    }

    private var headerSection: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
            VStack(alignment: .leading, spacing: 12) {
                ChordCrackLogo(size: .medium, style: .withText).accessibilityLabel("ChordCrack")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back, \(userDataManager.username)!")
                        .font(.subheadline.weight(.medium)).foregroundStyle(ColorTheme.textSecondary)
                    Text(userDataManager.totalGamesPlayed == 0 ? "Start with your first Daily Challenge below!" : "Keep building that streak!")
                        .font(.subheadline).foregroundStyle(ColorTheme.primaryGreen)
                }.fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 8) {
                NavigationLink(destination: SettingsView().environmentObject(userDataManager)) {
                    Image(systemName: "gearshape.fill").foregroundStyle(ColorTheme.textSecondary)
                        .frame(width: 44, height: 44).background(ColorTheme.cardBackground, in: Circle())
                }.accessibilityLabel("Settings")
                NavigationLink(destination: SocialFeaturesView().environmentObject(userDataManager)) {
                    Image(systemName: "person.2.fill").foregroundStyle(ColorTheme.primaryGreen)
                        .frame(width: 44, height: 44).background(ColorTheme.cardBackground, in: Circle())
                }.accessibilityLabel("Social")
                NavigationLink(destination: ProfileView().environmentObject(userDataManager).environmentObject(gameManager)) {
                    Text(String(userDataManager.username.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(ColorTheme.background)
                        .frame(width: 44, height: 44).background(ColorTheme.primaryGreen, in: Circle())
                }.accessibilityLabel("Profile")
            }
            .font(.system(size: 16, weight: .semibold))
            .disabled(DesignDemo.isEnabled)
            .accessibilityHint(DesignDemo.isEnabled ? "Account controls are unavailable in this preview" : "")
        }.padding(.horizontal, 24)
    }

    private var dailyChallengeCard: some View {
        NavigationLink(destination: HomePageDailyPuzzleView().environmentObject(gameManager).environmentObject(audioManager).environmentObject(userDataManager)) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Daily Challenge", systemImage: "calendar.badge.clock")
                            .font(.title2.weight(.bold)).foregroundStyle(ColorTheme.textPrimary)
                        Text(HomeDateFormatter.dailyFormat.string(from: currentDate))
                            .font(.subheadline.weight(.medium)).foregroundStyle(ColorTheme.textSecondary)
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "play.fill").font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ColorTheme.background).offset(x: 2)
                            .frame(width: 56, height: 56).background(ColorTheme.primaryGreen, in: Circle())
                            .overlay(Circle().stroke(ColorTheme.lightGreen.opacity(0.3), lineWidth: 2).padding(-3))
                            .accessibilityHidden(true)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))) {
                        Text("5 quick rounds").font(.subheadline.weight(.semibold)).foregroundStyle(ColorTheme.primaryGreen)
                        Text("Basic chords only").font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
                    }
                    Text(gameManager.isGameActive ? "Continue your session" : "Perfect for daily ear training")
                        .font(.caption).foregroundStyle(ColorTheme.textTertiary)
                }
                if gameManager.totalGames > 0 {
                    Label("Current Streak: \(gameManager.streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.orange)
                }
                VStack(spacing: 8) {
                    (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                        Text("Level \(userDataManager.currentLevel)").font(.caption.weight(.semibold))
                            .foregroundStyle(ColorTheme.primaryGreen).accessibilityIdentifier("home.level")
                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                        Text("\(max(0, userDataManager.currentXP % 1000))/1000 XP")
                            .font(.caption2.monospacedDigit()).foregroundStyle(ColorTheme.textTertiary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    ProgressView(value: min(1, max(0, userDataManager.levelProgress)))
                        .tint(ColorTheme.primaryGreen).accessibilityLabel("Level progress")
                }
            }
            .padding(24)
            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(ColorTheme.primaryGreen.opacity(0.3), lineWidth: 1))
        }
        .accessibilityIdentifier("home.daily")
        .accessibilityHint("Start or continue five rounds of basic chords")
        .buttonStyle(StudioPressStyle()).padding(.horizontal, 24)
    }

    private var quickStatsCard: some View {
        VStack(spacing: 16) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                Text("Your Progress Today").font(.headline).foregroundStyle(ColorTheme.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                NavigationLink(destination: StatsDashboardView().environmentObject(userDataManager).environmentObject(gameManager)) {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold)).foregroundStyle(ColorTheme.primaryGreen).frame(minHeight: 44)
                }.accessibilityIdentifier("home.dashboard")
            }
            Button {
                showingStats = true
                analytics.trackFeatureUsage("stats_quick_view")
            } label: {
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 20)) : AnyLayout(HStackLayout(spacing: 16))) {
                    HomeQuickStatItem(icon: "gamecontroller.fill", value: "\(userDataManager.totalGamesPlayed)", label: "Total Games", color: .blue)
                    if !dynamicTypeSize.isAccessibilitySize { Divider().frame(height: 32) }
                    HomeQuickStatItem(icon: "target", value: String(format: "%.0f%%", userDataManager.overallAccuracy), label: "Accuracy", color: ColorTheme.primaryGreen)
                    if !dynamicTypeSize.isAccessibilitySize { Divider().frame(height: 32) }
                    HomeQuickStatItem(icon: "crown.fill", value: "\(userDataManager.bestStreak)", label: "Best Streak", color: .orange)
                }.frame(maxWidth: .infinity).contentShape(Rectangle())
            }.buttonStyle(StudioPressStyle()).accessibilityHint("Opens your progress summary")
        }
        .padding(20).background(ColorTheme.cardBackground.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private var practiceModesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Practice Modes").font(.title2.weight(.bold)).foregroundStyle(ColorTheme.textPrimary)
                Text("Choose your skill level").font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }.padding(.horizontal, 24)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 16) { practiceCards }.padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) { practiceCards }.padding(.horizontal, 24)
                }.accessibilityIdentifier("home.practice-carousel")
            }
        }
    }

    @ViewBuilder private var practiceCards: some View {
        HomePracticeModeCard(title: "Power Chords", description: "Rock fundamentals", icon: "bolt.circle.fill", color: ColorTheme.power, difficulty: "Easy", progress: userDataManager.categoryAccuracy(for: GameTypeConstants.powerChords) / 100, destination: AnyView(PowerChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager)))
        HomePracticeModeCard(title: "Barre Chords", description: "Advanced patterns", icon: "guitars.fill", color: ColorTheme.barre, difficulty: "Hard", progress: userDataManager.categoryAccuracy(for: GameTypeConstants.barreChords) / 100, destination: AnyView(BarreChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager)))
        HomePracticeModeCard(title: "Blues Chords", description: "7th & extensions", icon: "music.quarternote.3", color: ColorTheme.blues, difficulty: "Expert", progress: userDataManager.categoryAccuracy(for: GameTypeConstants.bluesChords) / 100, destination: AnyView(BluesChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager)))
        HomePracticeModeCard(title: "Extended Chords", description: "sus, dim & aug", icon: "wand.and.stars", color: ColorTheme.extended, difficulty: "Expert", progress: userDataManager.categoryAccuracy(for: GameTypeConstants.extendedChords) / 100, destination: AnyView(ExtendedChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager)))
        HomePracticeModeCard(title: "Progressions", description: "Identify chord sequences", icon: "music.note.list", color: ColorTheme.progression, difficulty: "Advanced", progress: userDataManager.categoryAccuracy(for: GameTypeConstants.chordProgressions) / 100, destination: AnyView(ChordProgressionView().environmentObject(audioManager).environmentObject(userDataManager)))
        HomePracticeModeCard(title: "Mixed Mode", description: "All chord types", icon: "shuffle.circle.fill", color: ColorTheme.mixed, difficulty: "Master", progress: userDataManager.categoryAccuracy(for: GameTypeConstants.mixedPractice) / 100, destination: AnyView(MixedPracticeView().environmentObject(audioManager).environmentObject(userDataManager)))
        HomePracticeModeCard(title: "Chord Library", description: "Browse & learn", icon: "book.fill", color: ColorTheme.library, difficulty: "Reference", progress: 1, destination: AnyView(ChordLibraryView().environmentObject(audioManager)))
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                Text("Achievements").font(.title2.weight(.bold)).foregroundStyle(ColorTheme.textPrimary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("Keep practicing!").font(.subheadline).foregroundStyle(ColorTheme.primaryGreen)
            }.padding(.horizontal, 24)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach([Achievement.firstSteps, .streakMaster, .powerPlayer, .perfectRound], id: \.rawValue) { achievement in
                        HomeAchievementBadge(achievement: achievement, isUnlocked: userDataManager.achievements.contains(achievement))
                    }
                }.padding(.horizontal, 24)
            }
        }
    }
}

struct HomePageDailyPuzzleView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    var body: some View {
        GameView().environmentObject(gameManager).environmentObject(audioManager).environmentObject(userDataManager)
    }
}

struct HomeDateFormatter {
    static let dailyFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter
    }()
}
