import Foundation
import FirebaseAnalytics
import SwiftUI

/// Simple Firebase Analytics wrapper for ChordCrack
/// Handles all game and user engagement analytics
@MainActor
final class FirebaseAnalyticsManager: ObservableObject {
    
    static let shared = FirebaseAnalyticsManager()
    
    @Published var isAnalyticsEnabled = true
    
    private let userDefaults = UserDefaults.standard
    private var sessionStartTime: Date?
    
    private init() {
        loadPreferences()
        startSession()
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard isAnalyticsEnabled else { return }
        
        sessionStartTime = Date()
        
        // Firebase owns the reserved session_start event. Keep only our duration timer.
    }
    
    func endSession() {
        guard isAnalyticsEnabled, let startTime = sessionStartTime else { return }
        
        sessionStartTime = nil
        let sessionLength = Date().timeIntervalSince(startTime)
        
        Analytics.logEvent("session_end", parameters: [
            "session_length_seconds": Int(sessionLength),
            "session_length_minutes": Int(sessionLength / 60)
        ])
    }
    
    // MARK: - Game Analytics
    
    func trackGameStart(gameType: String) {
        guard isAnalyticsEnabled else { return }
        
        // Use Firebase's predefined game event
        Analytics.logEvent("level_start", parameters: [
            "level_name": gameType,
            "game_mode": gameType
        ])
    }
    
    func trackGameComplete(
        gameType: String,
        score: Int,
        streak: Int,
        accuracy: Double,
        roundsCompleted: Int,
        totalRounds: Int
    ) {
        guard isAnalyticsEnabled else { return }
        
        // Use Firebase's predefined game completion event
        Analytics.logEvent("level_end", parameters: [
            "level_name": gameType,
            "success": roundsCompleted == totalRounds,
            "score": score,
            "streak": streak,
            "accuracy": Int(accuracy),
            "rounds_completed": roundsCompleted,
            "total_rounds": totalRounds
        ])
        
        // Also log score separately for Firebase's built-in game analytics
        Analytics.logEvent("post_score", parameters: [
            "score": score,
            "level": gameType,
            "character": "guitar_player" // Firebase expects this parameter
        ])
    }
    
    func trackChordGuess(
        chordType: String,
        isCorrect: Bool,
        attemptNumber: Int,
        hintType: String,
        gameType: String
    ) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("chord_guess", parameters: [
            "chord_type": chordType,
            "is_correct": isCorrect,
            "attempt_number": attemptNumber,
            "hint_type": hintType,
            "game_mode": gameType
        ])
    }
    
    func trackGameAbandoned(gameType: String, roundsCompleted: Int) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("level_end", parameters: [
            "level_name": gameType,
            "success": false,
            "rounds_completed": roundsCompleted,
            "abandoned": true
        ])
    }
    
    // MARK: - Feature Usage
    
    func trackTutorialStart() {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("tutorial_begin", parameters: [:])
    }
    
    func trackTutorialComplete() {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("tutorial_complete", parameters: [:])
    }
    
    func trackFeatureUsage(_ featureName: String, properties: [String: Any] = [:]) {
        guard isAnalyticsEnabled else { return }
        
        var params = properties
        params["feature_name"] = featureName
        
        Analytics.logEvent("feature_used", parameters: params)
    }
    
    func trackAudioPlayback(chordType: String, audioOption: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("audio_playback", parameters: [
            "chord_type": chordType,
            "audio_option": audioOption
        ])
    }
    
    func trackReverseMode(action: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("reverse_mode", parameters: [
            "action": action
        ])
    }
    
    // MARK: - User Engagement
    
    func trackScreenView(_ screenName: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }
    
    func trackUsernameChange(oldUsername: String, newUsername: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("username_changed", parameters: [
            "old_username_length": oldUsername.count,
            "new_username_length": newUsername.count
        ])
    }
    
    func trackSignUpMethod(_ method: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("sign_up", parameters: [
            "method": method // "email" or "apple"
        ])
    }
    
    func trackSignInMethod(_ method: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("login", parameters: [
            "method": method // "email" or "apple"
        ])
    }
    
    // MARK: - Achievement Analytics
    
    func trackAchievementUnlocked(_ achievementId: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("unlock_achievement", parameters: [
            "achievement_id": achievementId
        ])
    }
    
    // MARK: - Error Tracking
    
    func trackError(_ errorType: String, context: String) {
        guard isAnalyticsEnabled else { return }
        
        Analytics.logEvent("app_error", parameters: [
            "error_type": errorType,
            "context": context
        ])
    }
    
    // MARK: - User Properties
    
    func setUserProperties(username: String, totalGames: Int, currentLevel: Int) {
        guard isAnalyticsEnabled else { return }
        
        // Set user properties for segmentation
        Analytics.setUserProperty(String(totalGames), forName: "total_games")
        Analytics.setUserProperty(String(currentLevel), forName: "user_level")
        Analytics.setUserProperty(String(username.count), forName: "username_length") // Don't store actual username for privacy
        
        // Set user ID for cross-platform tracking (optional)
        // Analytics.setUserID(hashedUserId) // Only if you want cross-device tracking
    }
    
    // MARK: - Privacy Controls
    
    func setAnalyticsEnabled(_ enabled: Bool) {
        let wasEnabled = isAnalyticsEnabled
        isAnalyticsEnabled = enabled
        userDefaults.set(enabled, forKey: "firebase_analytics_enabled")
        
        // Update Firebase setting
        Analytics.setAnalyticsCollectionEnabled(enabled)
        
        if enabled && !wasEnabled {
            startSession()
            Analytics.logEvent("analytics_enabled", parameters: [:])
        } else if !enabled {
            sessionStartTime = nil
        }
    }
    
    func resetAnalyticsData() {
        // Clear device data and the app instance ID, including while opted out.
        // Resetting is a privacy action, so do not log an event about it.
        Analytics.resetAnalyticsData()
        sessionStartTime = nil
    }
    
    // MARK: - Private Helpers
    
    /// One source of truth for startup and Settings; preserve the existing new-user default.
    nonisolated static func collectionPreference(in defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: "firebase_analytics_enabled") != nil else { return true }
        return defaults.bool(forKey: "firebase_analytics_enabled")
    }

    private func loadPreferences() {
        isAnalyticsEnabled = Self.collectionPreference(in: userDefaults)
        Analytics.setAnalyticsCollectionEnabled(isAnalyticsEnabled)
    }

}

// MARK: - Integration Extensions

extension FirebaseAnalyticsManager {
    
    /// Helper to track game session from GameManager
    func trackGameSession(from gameManager: GameManager, gameType: String, duration: TimeInterval = 0) {
        if gameManager.gameState == .gameOver && gameManager.isGameCompleted {
            // Game completed successfully
            let accuracy = gameManager.totalQuestions > 0 ?
                Double(gameManager.totalCorrect) / Double(gameManager.totalQuestions) * 100 : 0
            
            trackGameComplete(
                gameType: gameType,
                score: gameManager.score,
                streak: gameManager.bestStreak,
                accuracy: accuracy,
                roundsCompleted: gameManager.currentRound - 1,
                totalRounds: 5
            )
        } else if gameManager.isGameActive {
            // Game abandoned
            trackGameAbandoned(
                gameType: gameType,
                roundsCompleted: gameManager.currentRound - 1
            )
        }
    }
}
