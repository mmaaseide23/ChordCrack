import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    Circle()
                        .fill(ColorTheme.primaryGreen)
                        .frame(width: 90, height: 90)
                        .overlay(
                            Text(String(userDataManager.username.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: ColorTheme.primaryGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Text(userDataManager.username)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    // Dynamic title based on level
                    Text(getPlayerTitle())
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    // Level and XP bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Level \(userDataManager.currentLevel)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.primaryGreen)
                            
                            Spacer()
                            
                            let currentLevelXP = userDataManager.currentXP % 1000
                            Text("\(currentLevelXP)/1000 XP")
                                .font(.system(size: 10))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        
                        ProgressView(value: userDataManager.levelProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: ColorTheme.primaryGreen))
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)
                
                // Statistics Grid - Using REAL DATA
                VStack(spacing: 16) {
                    Text("Your Statistics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ProfileStatCard(
                            title: "Games",
                            value: "\(userDataManager.totalGamesPlayed)",
                            icon: "gamecontroller"
                        )
                        ProfileStatCard(
                            title: "Best Score",
                            value: "\(userDataManager.bestScore)",
                            icon: "star.fill"
                        )
                        ProfileStatCard(
                            title: "Best Streak",
                            value: "\(userDataManager.bestStreak)",
                            icon: "flame.fill"
                        )
                        ProfileStatCard(
                            title: "Accuracy",
                            value: String(format: "%.0f%%", userDataManager.overallAccuracy),
                            icon: "target"
                        )
                        ProfileStatCard(
                            title: "Avg Score",
                            value: String(format: "%.0f", userDataManager.averageScore),
                            icon: "chart.bar.fill"
                        )
                        ProfileStatCard(
                            title: "Correct",
                            value: "\(userDataManager.totalCorrectAnswers)",
                            icon: "checkmark.circle.fill"
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Achievements - Using REAL DATA
                VStack(spacing: 16) {
                    Text("Achievements")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Achievement.allCases, id: \.rawValue) { achievement in
                            AchievementBadge(
                                title: achievement.title,
                                icon: achievement.icon,
                                isUnlocked: userDataManager.achievements.contains(achievement),
                                color: achievement.color
                            )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Practice Progress - Using REAL CATEGORY DATA
                VStack(spacing: 16) {
                    Text("Practice Progress")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        // Power Chords
                        PracticeProgressRow(
                            category: .power,
                            progress: userDataManager.categoryAccuracy(for: "powerChords") / 100,
                            completedSessions: userDataManager.categoryStats["powerChords"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "powerChords")
                        )
                        
                        // Barre Chords
                        PracticeProgressRow(
                            category: .barre,
                            progress: userDataManager.categoryAccuracy(for: "barreChords") / 100,
                            completedSessions: userDataManager.categoryStats["barreChords"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "barreChords")
                        )
                        
                        // Blues Chords
                        PracticeProgressRow(
                            category: .blues,
                            progress: userDataManager.categoryAccuracy(for: "bluesChords") / 100,
                            completedSessions: userDataManager.categoryStats["bluesChords"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "bluesChords")
                        )
                        
                        // Daily Challenge (Basic)
                        PracticeProgressRow(
                            category: .basic,
                            progress: userDataManager.categoryAccuracy(for: "dailyChallenge") / 100,
                            completedSessions: userDataManager.categoryStats["dailyChallenge"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "dailyChallenge")
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Settings
                VStack(spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        SettingsRow(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right") {
                            userDataManager.signOut()
                            presentationMode.wrappedValue.dismiss()
                        }
                        
                        SettingsRow(title: "Reset Tutorial", icon: "arrow.clockwise") {
                            userDataManager.hasSeenTutorial = false
                            // saveUserData is now called internally
                        }
                        
                        SettingsRow(title: "Connection Status", icon: "wifi") {
                            // Shows connection status
                        }
                        
                        SettingsRow(title: "About ChordCrack", icon: "info.circle") {}
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Connection Status Indicator
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(connectionStatusText)
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .padding(.top, 8)
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background)
    }
    
    private func getPlayerTitle() -> String {
        let level = userDataManager.currentLevel
        switch level {
        case 1...5:
            return "Chord Beginner"
        case 6...10:
            return "Chord Student"
        case 11...20:
            return "Chord Apprentice"
        case 21...30:
            return "Chord Player"
        case 31...50:
            return "Chord Expert"
        case 51...75:
            return "Chord Master"
        case 76...99:
            return "Chord Virtuoso"
        default:
            return "Chord Legend"
        }
    }
    
    private var connectionStatusColor: Color {
        switch userDataManager.connectionStatus {
        case .online:
            return Color.green
        case .offline:
            return Color.red
        case .syncing:
            return Color.orange
        }
    }
    
    private var connectionStatusText: String {
        switch userDataManager.connectionStatus {
        case .online:
            return "Connected to server"
        case .offline:
            return "Offline - Data saved locally"
        case .syncing:
            return "Syncing..."
        }
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ColorTheme.primaryGreen)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.secondaryBackground)
        )
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    let isUnlocked: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isUnlocked ? color : ColorTheme.textSecondary.opacity(0.5))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 85, height: 75)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? color.opacity(0.15) : ColorTheme.secondaryBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnlocked ? color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(isUnlocked ? 1.0 : 0.95)
    }
}

struct PracticeProgressRow: View {
    let category: ChordCategory
    let progress: Double
    let completedSessions: Int
    let accuracy: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .foregroundColor(category.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", accuracy))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(category.color)
                }
                
                Text("\(completedSessions) sessions completed")
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textSecondary)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: category.color))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTheme.secondaryBackground)
        )
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(ColorTheme.primaryGreen)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(ColorTheme.textSecondary)
                    .font(.system(size: 12))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ColorTheme.secondaryBackground)
            )
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(UserDataManager())
            .environmentObject(GameManager())
    }
}
