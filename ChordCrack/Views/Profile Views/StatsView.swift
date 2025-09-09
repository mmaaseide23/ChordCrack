import SwiftUI

struct StatsView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var userDataManager: UserDataManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ColorTheme.textPrimary)
            
            // Using REAL data from userDataManager
            HStack(spacing: 20) {
                SimpleStatCard(
                    title: "Games Played",
                    value: "\(userDataManager.totalGamesPlayed)"
                )
                SimpleStatCard(
                    title: "Best Score",
                    value: "\(userDataManager.bestScore)"
                )
                SimpleStatCard(
                    title: "Best Streak",
                    value: "\(userDataManager.bestStreak)"
                )
            }
            
            // Overall accuracy
            HStack(spacing: 20) {
                SimpleStatCard(
                    title: "Accuracy",
                    value: String(format: "%.0f%%", userDataManager.overallAccuracy)
                )
                SimpleStatCard(
                    title: "Total Correct",
                    value: "\(userDataManager.totalCorrectAnswers)"
                )
                SimpleStatCard(
                    title: "Avg Score",
                    value: String(format: "%.0f", userDataManager.averageScore)
                )
            }
            
            // Current game progress (if playing)
            if gameManager.isGameActive {
                VStack(spacing: 8) {
                    Text("Current Game")
                        .font(.headline)
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    HStack {
                        Text("Round \(gameManager.currentRound) of 5")
                            .font(.subheadline)
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Spacer()
                        
                        Text("Score: \(gameManager.score)")
                            .font(.subheadline)
                            .foregroundColor(ColorTheme.primaryGreen)
                    }
                    
                    ProgressView(value: Double(gameManager.currentRound - 1), total: 5)
                        .progressViewStyle(LinearProgressViewStyle(tint: ColorTheme.primaryGreen))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                }
                .padding(.top)
            }
            
            // Category breakdown
            if !userDataManager.categoryStats.isEmpty {
                VStack(spacing: 12) {
                    Text("Category Performance")
                        .font(.headline)
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    ForEach(["dailyChallenge", "powerChords", "barreChords", "bluesChords"], id: \.self) { category in
                        if let stats = userDataManager.categoryStats[category], stats.sessionsPlayed > 0 {
                            HStack {
                                Text(categoryDisplayName(category))
                                    .font(.subheadline)
                                    .foregroundColor(ColorTheme.textSecondary)
                                
                                Spacer()
                                
                                Text("\(stats.sessionsPlayed) sessions")
                                    .font(.caption)
                                    .foregroundColor(ColorTheme.textTertiary)
                                
                                Text(String(format: "%.0f%%", stats.accuracy))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(categoryColor(category))
                            }
                        }
                    }
                }
                .padding(.top)
            }
        }
        .padding()
        .themedCard()
    }
    
    private func categoryDisplayName(_ category: String) -> String {
        switch category {
        case "dailyChallenge":
            return "Daily Challenge"
        case "powerChords":
            return "Power Chords"
        case "barreChords":
            return "Barre Chords"
        case "bluesChords":
            return "Blues Chords"
        default:
            return category
        }
    }
    
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "dailyChallenge":
            return ColorTheme.primaryGreen
        case "powerChords":
            return Color.orange
        case "barreChords":
            return Color.purple
        case "bluesChords":
            return Color.blue
        default:
            return ColorTheme.textSecondary
        }
    }
}

// Using a different name to avoid conflict with SharedUIComponents
struct SimpleStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTheme.primaryGreen)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.secondaryBackground)
        )
    }
}

#Preview {
    StatsView()
        .environmentObject(GameManager())
        .environmentObject(UserDataManager())
        .themedBackground()
}
