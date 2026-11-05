import SwiftUI

struct HomeView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @ObservedObject private var avatars = ProfileAvatarStore.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var currentDate = Date()
    @State private var showingStats = false
    @State private var showingFiveRoundPractice = false
    @State private var showingDailyRiff = false
    private let analytics = FirebaseAnalyticsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                dailyRiffCard
                quickStatsCard
                otherModesSection
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
        .fullScreenCover(isPresented: $showingFiveRoundPractice) {
            FiveRoundPracticeView()
        }
        .fullScreenCover(isPresented: $showingDailyRiff) {
            DailyRiffView()
        }
    }

    private var dailyRiffCard: some View {
        Button { showingDailyRiff = true } label: {
            VStack(alignment: .leading, spacing: 16) {
                Label("NEW · SHARED DAILY PUZZLE", systemImage: "sparkles")
                    .font(.caption.weight(.heavy))
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Riff").font(.largeTitle.bold())
                        Text("Five puzzles. One fresh riff every day.")
                            .font(.headline).fixedSize(horizontal: false, vertical: true)
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                        Image(systemName: "waveform").font(.system(size: 34, weight: .bold))
                            .padding(.top, 8).accessibilityHidden(true)
                    }
                }
                Text("Feel it. Match it. Spot the switch.")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Label("Open today’s riff", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.bold)).padding(.top, 4)
            }
            .foregroundStyle(ColorTheme.background).frame(maxWidth: .infinity, alignment: .leading)
            .padding(24).background(ColorTheme.primaryGreen, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(StudioPressStyle()).padding(.horizontal, 24)
            .accessibilityIdentifier("home.daily-riff")
            .accessibilityHint("Five daily listening puzzles with a spoiler-free result to share")
    }

    private var headerSection: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
            VStack(alignment: .leading, spacing: 12) {
                ChordCrackLogo(size: .medium, style: .withText).accessibilityLabel("ChordCrack")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back, \(userDataManager.username)!")
                        .font(.subheadline.weight(.medium)).foregroundStyle(ColorTheme.textSecondary)
                    Text("Today’s Daily Riff is ready.")
                        .font(.subheadline).foregroundStyle(ColorTheme.primaryGreen)
                }.fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(spacing: 8) {
                NavigationLink(destination: SettingsView().environmentObject(userDataManager)) {
                    Image(systemName: "gearshape.fill").foregroundStyle(ColorTheme.textSecondary)
                        .frame(width: 44, height: 44).background(ColorTheme.cardBackground, in: Circle())
                }.accessibilityLabel("Settings").disabled(DesignDemo.isEnabled)
                NavigationLink(destination: SocialFeaturesView().environmentObject(userDataManager)) {
                    Image(systemName: "person.2.fill").foregroundStyle(ColorTheme.primaryGreen)
                        .frame(width: 44, height: 44).background(ColorTheme.cardBackground, in: Circle())
                }.accessibilityLabel("Social").disabled(DesignDemo.isEnabled)
                NavigationLink(destination: ProfileView().environmentObject(userDataManager).environmentObject(gameManager)) {
                    ProfileAvatarBadge(avatar: avatars.avatar, username: userDataManager.username)
                }.accessibilityLabel("Profile").accessibilityValue(avatars.avatar.title).accessibilityIdentifier("home.profile")
            }
            .font(.system(size: 16, weight: .semibold))
        }.padding(.horizontal, 24)
    }

    private var otherModesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More ways to practice").font(.title3.bold()).foregroundStyle(ColorTheme.textPrimary)
            VStack(spacing: 0) {
                dailyChallengeCard
                Divider().padding(.horizontal, 18)
                fiveRoundPracticeCard
            }
            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
        }.padding(.horizontal, 24)
    }

    private var dailyChallengeCard: some View {
        NavigationLink(destination: HomePageDailyPuzzleView().environmentObject(gameManager).environmentObject(audioManager).environmentObject(userDataManager)) {
            secondaryModeRow(title: "Daily Challenge",
                subtitle: gameManager.isGameActive ? "Continue your five basic-chord rounds" : "5 basic-chord rounds · \(HomeDateFormatter.dailyFormat.string(from: currentDate))",
                symbol: "calendar.badge.clock", color: ColorTheme.primaryGreen)
        }
        .accessibilityIdentifier("home.daily")
        .accessibilityHint("Start or continue five rounds of basic chords")
        .buttonStyle(StudioPressStyle())
    }

    private var fiveRoundPracticeCard: some View {
        Button { showingFiveRoundPractice = true } label: {
            secondaryModeRow(title: "Five-round practice", subtitle: "Major & minor · A fresh session with no effect on your stats",
                symbol: "music.note", color: ColorTheme.warning)
        }
        .buttonStyle(StudioPressStyle())
        .accessibilityIdentifier("practice.five-round")
        .accessibilityHint("Opens five major and minor rounds with optional comparison replay")
    }

    private func secondaryModeRow(title: String, subtitle: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: symbol).font(.title3).foregroundStyle(color)
                    .frame(width: 34).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline).foregroundStyle(ColorTheme.textPrimary)
                Text(subtitle).font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(ColorTheme.textSecondary).accessibilityHidden(true)
            }
        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(18).contentShape(Rectangle())
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(userDataManager.currentLevel) · \(max(0, userDataManager.currentXP % 1000))/1000 XP")
                    .font(.caption.weight(.semibold)).foregroundStyle(ColorTheme.primaryGreen)
                    .accessibilityIdentifier("home.level")
                ProgressView(value: min(1, max(0, userDataManager.levelProgress)))
                    .tint(ColorTheme.primaryGreen).accessibilityLabel("Level progress")
                if gameManager.totalGames > 0 {
                    Label("Current Streak: \(gameManager.streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.orange)
                }
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
