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
                    
                    Text("ChordCrack Champion")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .padding(.top, 20)
                
                // Statistics Grid
                VStack(spacing: 16) {
                    Text("Your Statistics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ProfileStatCard(title: "Games", value: "\(gameManager.totalGames)", icon: "gamecontroller")
                        ProfileStatCard(title: "Score", value: "\(gameManager.score)", icon: "star.fill")
                        ProfileStatCard(title: "Streak", value: "\(gameManager.streak)", icon: "flame.fill")
                        ProfileStatCard(title: "Accuracy", value: "85%", icon: "target")
                        ProfileStatCard(title: "Barre", value: "67%", icon: "guitars.fill")
                        ProfileStatCard(title: "Blues", value: "43%", icon: "music.quarternote.3")
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Achievements
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
                        AchievementBadge(title: "First Steps", icon: "music.note", isUnlocked: gameManager.totalGames > 0, color: ColorTheme.primaryGreen)
                        AchievementBadge(title: "Streak Master", icon: "flame", isUnlocked: gameManager.streak >= 5, color: Color.orange)
                        AchievementBadge(title: "Perfect Round", icon: "star.circle.fill", isUnlocked: false, color: Color.yellow)
                        AchievementBadge(title: "Barre Expert", icon: "guitars", isUnlocked: false, color: Color.purple)
                        AchievementBadge(title: "Blues Scholar", icon: "music.quarternote.3", isUnlocked: false, color: Color.blue)
                        AchievementBadge(title: "Power Player", icon: "bolt", isUnlocked: false, color: Color.orange)
                        AchievementBadge(title: "Chord Wizard", icon: "wand.and.stars", isUnlocked: false, color: Color.purple)
                        AchievementBadge(title: "Perfect Pitch", icon: "ear", isUnlocked: false, color: ColorTheme.lightGreen)
                        AchievementBadge(title: "Speed Demon", icon: "timer", isUnlocked: false, color: Color.cyan)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Practice Progress
                VStack(spacing: 16) {
                    Text("Practice Progress")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        PracticeProgressRow(
                            category: .power,
                            progress: 0.89,
                            completedSessions: 16,
                            totalSessions: 18
                        )
                        
                        PracticeProgressRow(
                            category: .barre,
                            progress: 0.67,
                            completedSessions: 12,
                            totalSessions: 18
                        )
                        
                        PracticeProgressRow(
                            category: .blues,
                            progress: 0.43,
                            completedSessions: 8,
                            totalSessions: 19
                        )
                        
                        PracticeProgressRow(
                            category: .basic,
                            progress: 0.92,
                            completedSessions: 23,
                            totalSessions: 25
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
                        SettingsRow(title: "Change Username", icon: "person.circle") {
                            userDataManager.isUsernameSet = false
                            presentationMode.wrappedValue.dismiss()
                        }
                        
                        SettingsRow(title: "Reset Statistics", icon: "arrow.clockwise") {}
                        SettingsRow(title: "Audio Settings", icon: "speaker.wave.2") {}
                        SettingsRow(title: "About ChordCrack", icon: "info.circle") {}
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background)
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
    let totalSessions: Int
    
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
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(category.color)
                }
                
                Text("\(completedSessions)/\(totalSessions) sessions")
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
