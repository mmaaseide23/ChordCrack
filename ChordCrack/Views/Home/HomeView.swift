import SwiftUI

struct HomeView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var userDataManager: UserDataManager
    @State private var currentDate = Date()
    @State private var showingStats = false

    private let analytics = FirebaseAnalyticsManager.shared

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
            analytics.trackScreenView("home")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                ChordCrackLogo(size: .medium, style: .withText)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back, \(userDataManager.username)!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)

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

    // MARK: - Daily Challenge Card

    private var dailyChallengeCard: some View {
        NavigationLink(destination: HomePageDailyPuzzleView()
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

                        Text(HomeDateFormatter.dailyFormat.string(from: currentDate))
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

    // MARK: - Quick Stats Card

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
            analytics.trackFeatureUsage("stats_quick_view")
        }
        .sheet(isPresented: $showingStats) {
            HomeStatsDetailView()
                .environmentObject(userDataManager)
                .environmentObject(gameManager)
        }
    }

    // MARK: - Practice Modes Section

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
                        color: Color.red,
                        difficulty: "Easy",
                        progress: userDataManager.categoryAccuracy(for: GameTypeConstants.powerChords) / 100.0,
                        destination: AnyView(PowerChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                    )

                    HomePracticeModeCard(
                        title: "Barre Chords",
                        description: "Advanced patterns",
                        icon: "guitars.fill",
                        color: Color.orange,
                        difficulty: "Hard",
                        progress: userDataManager.categoryAccuracy(for: GameTypeConstants.barreChords) / 100.0,
                        destination: AnyView(BarreChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                    )

                    HomePracticeModeCard(
                        title: "Blues Chords",
                        description: "7th & extensions",
                        icon: "music.quarternote.3",
                        color: Color.blue,
                        difficulty: "Expert",
                        progress: userDataManager.categoryAccuracy(for: GameTypeConstants.bluesChords) / 100.0,
                        destination: AnyView(BluesChordsPracticeView().environmentObject(audioManager).environmentObject(userDataManager))
                    )

                    HomePracticeModeCard(
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

    // MARK: - Achievements Preview Section

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

// MARK: - Daily Puzzle View

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

// MARK: - Date Formatter

struct HomeDateFormatter {
    static let dailyFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter
    }()
}
