import SwiftUI

// MARK: - Result View for Reverse Mode
struct ReverseResultView: View {
    @EnvironmentObject var reverseManager: ReverseModeManager
    @State private var showingAnimation = false
    
    var body: some View {
        let isCorrect = reverseManager.isAnswerCorrect
        
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCorrect ? ColorTheme.primaryPurple.opacity(0.2) : ColorTheme.error.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(showingAnimation ? 1.1 : 0.9)
                
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isCorrect ? ColorTheme.primaryPurple : ColorTheme.error)
                    .scaleEffect(showingAnimation ? 1.0 : 0.8)
            }
            
            VStack(spacing: 8) {
                Text(isCorrect ? "Perfect!" : "Not Quite!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(isCorrect ? ColorTheme.primaryPurple : ColorTheme.error)
                
                if !isCorrect {
                    Text("Check the correct finger positions shown in green")
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                if isCorrect {
                    let points = reverseManager.calculatePoints()
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(Color.orange)
                        
                        Text("+\(points) points")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                }
                
                if reverseManager.currentStreak >= 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Color.orange)
                        
                        Text("Streak: \(reverseManager.currentStreak)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.reverseCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCorrect ? ColorTheme.primaryPurple.opacity(0.3) : ColorTheme.error.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showingAnimation = true
            }
        }
    }
}


// MARK: - Completed View for Reverse Mode
struct ReverseCompletedView: View {
    @EnvironmentObject var reverseManager: ReverseModeManager
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingCelebration = false
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(ColorTheme.primaryPurple.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(showingCelebration ? 1.2 : 1.0)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color.yellow)
                    .rotationEffect(.degrees(showingCelebration ? 360 : 0))
            }
            
            VStack(spacing: 12) {
                Text("Reverse Mode Complete!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        ScoreStatItem(label: "Final Score", value: "\(reverseManager.score)", color: ColorTheme.primaryPurple)
                        ScoreStatItem(label: "Best Streak", value: "\(reverseManager.bestStreak)", color: Color.orange)
                    }
                    
                    HStack(spacing: 16) {
                        ScoreStatItem(label: "Accuracy", value: "\(reverseManager.totalCorrect)/\(reverseManager.totalQuestions)", color: ColorTheme.lightPurple)
                        ScoreStatItem(label: "XP Earned", value: "+\(calculateXP())", color: ColorTheme.brightPurple)
                    }
                    
                    Text(getPerformanceMessage())
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            
            VStack(spacing: 12) {
                Button("Play Again") {
                    reverseManager.startNewGame(mode: reverseManager.gameMode)
                }
                .buttonStyle(PrimaryGameButtonStyle(color: ColorTheme.primaryPurple))
                
                Button("Back to Home") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(SecondaryGameButtonStyle())
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
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.3)) {
                showingCelebration = true
            }
        }
    }
    
    private func calculateXP() -> Int {
        return reverseManager.score / 10 + reverseManager.bestStreak * 5
    }
    
    private func getPerformanceMessage() -> String {
        let accuracy = Double(reverseManager.totalCorrect) / Double(reverseManager.totalQuestions) * 100.0
        
        if accuracy >= 90 {
            return "Outstanding! You're a chord building master!"
        } else if accuracy >= 70 {
            return "Great job! Your fretboard knowledge is really improving!"
        } else if accuracy >= 50 {
            return "Good progress! Keep practicing to improve your accuracy."
        } else {
            return "Keep practicing! Every attempt makes you better."
        }
    }
}
