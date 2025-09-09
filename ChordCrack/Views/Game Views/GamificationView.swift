import SwiftUI

/// Comprehensive gamification system with achievements, daily rewards, and progression
struct GamificationView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @StateObject private var rewardManager = DailyRewardManager()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Achievements")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                // Daily streak indicator
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color.orange)
                    
                    Text("\(rewardManager.currentStreak)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Tab Selector
            Picker("Achievement Tab", selection: $selectedTab) {
                Text("Achievements").tag(0)
                Text("Daily Rewards").tag(1)
                Text("Season Pass").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Content
            TabView(selection: $selectedTab) {
                AchievementGridView()
                    .environmentObject(userDataManager)
                    .tag(0)
                
                DailyRewardsView()
                    .environmentObject(rewardManager)
                    .environmentObject(userDataManager)
                    .tag(1)
                
                SeasonPassView()
                    .environmentObject(userDataManager)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            rewardManager.checkDailyReward()
        }
    }
}

// MARK: - Achievement Grid

struct AchievementGridView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    
    private let achievementCategories: [(String, [Achievement])] = [
        ("Getting Started", [.firstSteps, .streakMaster, .perfectRound]),
        ("Mastery", [.barreExpert, .bluesScholar, .powerPlayer]),
        ("Expert", [.chordWizard, .perfectPitch, .speedDemon])
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(achievementCategories, id: \.0) { category, achievements in
                    achievementCategoryView(title: category, achievements: achievements)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    private func achievementCategoryView(title: String, achievements: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(achievements, id: \.rawValue) { achievement in
                    EnhancedAchievementBadge(
                        achievement: achievement,
                        isUnlocked: userDataManager.achievements.contains(achievement)
                    )
                }
            }
        }
    }
}

struct EnhancedAchievementBadge: View {
    let achievement: Achievement
    let isUnlocked: Bool
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? achievement.color.opacity(0.2) : ColorTheme.textTertiary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: achievement.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isUnlocked ? achievement.color : ColorTheme.textTertiary.opacity(0.5))
                    
                    if isUnlocked {
                        Circle()
                            .stroke(achievement.color, lineWidth: 2)
                            .frame(width: 50, height: 50)
                    }
                }
                
                Text(achievement.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 90, height: 85)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? achievement.color.opacity(0.1) : ColorTheme.secondaryBackground.opacity(0.5))
            )
            .scaleEffect(isUnlocked ? 1.0 : 0.95)
        }
        .sheet(isPresented: $showingDetails) {
            AchievementDetailView(achievement: achievement, isUnlocked: isUnlocked)
        }
    }
}

// MARK: - Daily Rewards System

struct DailyRewardsView: View {
    @EnvironmentObject var rewardManager: DailyRewardManager
    @EnvironmentObject var userDataManager: UserDataManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Daily streak section
                dailyStreakSection
                
                // Weekly rewards grid
                weeklyRewardsGrid
                
                // Daily bonus section
                dailyBonusSection
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    private var dailyStreakSection: some View {
        VStack(spacing: 16) {
            Text("Daily Streak")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(day <= rewardManager.currentStreak ? Color.orange : ColorTheme.textTertiary.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("\(day)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(day <= rewardManager.currentStreak ? .white : ColorTheme.textTertiary)
                            )
                        
                        Text(rewardManager.getStreakReward(for: day))
                            .font(.system(size: 8))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
        )
    }
    
    private var weeklyRewardsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Challenges")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(rewardManager.weeklyRewards, id: \.id) { reward in
                    WeeklyRewardCard(reward: reward)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
        )
    }
    
    private var dailyBonusSection: some View {
        VStack(spacing: 16) {
            Text("Daily Bonus")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            if rewardManager.canClaimDailyBonus {
                Button(action: { rewardManager.claimDailyBonus() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Claim Daily Bonus!")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(ColorTheme.primaryGreen)
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Text("Bonus Claimed!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Text("Come back tomorrow for another bonus")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
        )
    }
}

// MARK: - Season Pass

struct SeasonPassView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @State private var seasonLevel = 15 // Mock current level
    
    private let seasonRewards = [
        SeasonReward(level: 1, title: "Welcome Badge", icon: "star.fill", color: ColorTheme.primaryGreen),
        SeasonReward(level: 5, title: "Speed Boost", icon: "bolt.fill", color: Color.orange),
        SeasonReward(level: 10, title: "Chord Master", icon: "guitars.fill", color: Color.purple),
        SeasonReward(level: 15, title: "Perfect Pitch", icon: "ear.fill", color: Color.blue),
        SeasonReward(level: 20, title: "Legend Status", icon: "crown.fill", color: Color.yellow),
        SeasonReward(level: 25, title: "Hall of Fame", icon: "trophy.fill", color: Color.red)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Season header
                VStack(spacing: 8) {
                    Text("Season 1: Musical Journey")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("Level \(seasonLevel)")
                        .font(.system(size: 16))
                        .foregroundColor(Color.blue)
                }
                .padding(.top, 20)
                
                // Progress bar
                VStack(spacing: 8) {
                    HStack {
                        Text("Progress to next level")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Spacer()
                        
                        Text("650/1000 XP")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    
                    ProgressView(value: 0.65)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
                .padding(.horizontal, 20)
                
                // Season rewards
                LazyVStack(spacing: 12) {
                    ForEach(seasonRewards, id: \.level) { reward in
                        SeasonRewardRow(reward: reward, currentLevel: seasonLevel)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
    }
}

struct SeasonRewardRow: View {
    let reward: SeasonReward
    let currentLevel: Int
    
    private var isUnlocked: Bool { currentLevel >= reward.level }
    private var isCurrent: Bool { currentLevel == reward.level }
    
    var body: some View {
        HStack(spacing: 16) {
            // Level badge
            ZStack {
                Circle()
                    .fill(isUnlocked ? reward.color : ColorTheme.textTertiary.opacity(0.3))
                    .frame(width: 40, height: 40)
                
                if isUnlocked {
                    Image(systemName: reward.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(reward.level)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ColorTheme.textTertiary)
                }
            }
            
            // Reward info
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textSecondary)
                
                Text("Level \(reward.level)")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textTertiary)
            }
            
            Spacer()
            
            if isUnlocked {
                Text("UNLOCKED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(reward.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(reward.color.opacity(0.2))
                    )
            } else {
                Text("LOCKED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ColorTheme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(ColorTheme.textTertiary.opacity(0.2))
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrent ? reward.color.opacity(0.1) : ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrent ? reward.color.opacity(0.5) : Color.clear, lineWidth: 2)
                )
        )
    }
}

// MARK: - Daily Reward Manager

class DailyRewardManager: ObservableObject {
    @Published var currentStreak = 3 // Mock data
    @Published var canClaimDailyBonus = true
    @Published var lastClaimDate: Date?
    @Published var weeklyRewards: [WeeklyReward] = []
    
    init() {
        generateWeeklyRewards()
    }
    
    func checkDailyReward() {
        // Check if user can claim daily bonus
        if let lastClaim = lastClaimDate {
            let calendar = Calendar.current
            canClaimDailyBonus = !calendar.isDateInToday(lastClaim)
        }
    }
    
    func claimDailyBonus() {
        guard canClaimDailyBonus else { return }
        
        lastClaimDate = Date()
        canClaimDailyBonus = false
        currentStreak += 1
        
        // Add bonus points or rewards here
    }
    
    func getStreakReward(for day: Int) -> String {
        switch day {
        case 1: return "10 pts"
        case 2: return "15 pts"
        case 3: return "20 pts"
        case 4: return "25 pts"
        case 5: return "30 pts"
        case 6: return "40 pts"
        case 7: return "Badge"
        default: return ""
        }
    }
    
    private func generateWeeklyRewards() {
        weeklyRewards = [
            WeeklyReward(id: "1", title: "Chord Master", description: "Complete 5 daily challenges", progress: 3, target: 5, isCompleted: false),
            WeeklyReward(id: "2", title: "Practice Makes Perfect", description: "Try all practice modes", progress: 2, target: 4, isCompleted: false),
            WeeklyReward(id: "3", title: "Social Butterfly", description: "Add 3 friends", progress: 1, target: 3, isCompleted: false),
            WeeklyReward(id: "4", title: "Streak Keeper", description: "Maintain 5-day streak", progress: 5, target: 5, isCompleted: true)
        ]
    }
}

struct WeeklyRewardCard: View {
    let reward: WeeklyReward
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(reward.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                if reward.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorTheme.primaryGreen)
                }
            }
            
            Text(reward.description)
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textSecondary)
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(reward.progress)/\(reward.target)")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Spacer()
                }
                
                ProgressView(value: Double(reward.progress), total: Double(reward.target))
                    .progressViewStyle(LinearProgressViewStyle(tint: reward.isCompleted ? ColorTheme.primaryGreen : Color.blue))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(reward.isCompleted ? ColorTheme.primaryGreen.opacity(0.1) : ColorTheme.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(reward.isCompleted ? ColorTheme.primaryGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Achievement Detail View

struct AchievementDetailView: View {
    let achievement: Achievement
    let isUnlocked: Bool
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    Circle()
                        .fill(achievement.color.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: achievement.icon)
                                .font(.system(size: 50))
                                .foregroundColor(achievement.color)
                        )
                    
                    VStack(spacing: 8) {
                        Text(achievement.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                        
                        Text(achievement.description)
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                if isUnlocked {
                    VStack(spacing: 12) {
                        Text("ACHIEVEMENT UNLOCKED!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(achievement.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(achievement.color.opacity(0.2))
                            )
                        
                        Text("You've mastered this skill. Keep up the great work!")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Keep practicing to unlock this achievement!")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .background(ColorTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(ColorTheme.primaryGreen)
            )
        }
    }
}

// MARK: - Supporting Data Models

struct SeasonReward {
    let level: Int
    let title: String
    let icon: String
    let color: Color
}

struct WeeklyReward: Identifiable {
    let id: String
    let title: String
    let description: String
    let progress: Int
    let target: Int
    let isCompleted: Bool
}
