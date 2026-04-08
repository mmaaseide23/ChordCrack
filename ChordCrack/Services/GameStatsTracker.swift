import Foundation

class GameStatsTracker {

    /// Records a game session with proper categorization
    static func recordSession(
        userDataManager: UserDataManager,
        gameType: String,
        score: Int,
        streak: Int,
        correctAnswers: Int,
        totalQuestions: Int
    ) {
        guard score >= 0, streak >= 0, correctAnswers >= 0,
              totalQuestions > 0, correctAnswers <= totalQuestions else {
            debugLog("[GameStatsTracker] Invalid game session data - not recording")
            return
        }

        Task { @MainActor in
            userDataManager.recordGameSession(
                score: score,
                streak: streak,
                correctAnswers: correctAnswers,
                totalQuestions: totalQuestions,
                gameType: gameType
            )
        }
    }
}
