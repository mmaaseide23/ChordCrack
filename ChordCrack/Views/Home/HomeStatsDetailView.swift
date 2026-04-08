import SwiftUI

struct HomeStatsDetailView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
