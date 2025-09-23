import Foundation
import Combine
import SwiftUI

// MARK: - Supporting Models

struct CategoryStats: Codable {
    var sessionsPlayed: Int = 0
    var bestScore: Int = 0
    var correctAnswers: Int = 0
    var totalQuestions: Int = 0
    var totalScore: Int = 0
    var averageScore: Double = 0.0
    
    var accuracy: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return (Double(correctAnswers) / Double(totalQuestions)) * 100.0
    }
}

enum Achievement: String, CaseIterable, Codable {
    case firstGame = "first_game"
    case perfectScore = "perfect_score"
    case streakMaster = "streak_master"
    case quickLearner = "quick_learner"
    case dedicated = "dedicated"
    case expert = "expert"
    
    var title: String {
        switch self {
        case .firstGame: return "First Steps"
        case .perfectScore: return "Perfect!"
        case .streakMaster: return "Streak Master"
        case .quickLearner: return "Quick Learner"
        case .dedicated: return "Dedicated"
        case .expert: return "Expert"
        }
    }
    
    var description: String {
        switch self {
        case .firstGame: return "Complete your first game"
        case .perfectScore: return "Get a perfect score"
        case .streakMaster: return "Achieve a 10+ streak"
        case .quickLearner: return "Complete 5 games"
        case .dedicated: return "Play 7 days in a row"
        case .expert: return "Master all chord types"
        }
    }
    
    var icon: String {
        switch self {
        case .firstGame: return "star"
        case .perfectScore: return "star.fill"
        case .streakMaster: return "flame.fill"
        case .quickLearner: return "bolt.fill"
        case .dedicated: return "calendar"
        case .expert: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .firstGame: return .blue
        case .perfectScore: return .yellow
        case .streakMaster: return .orange
        case .quickLearner: return .green
        case .dedicated: return .purple
        case .expert: return .red
        }
    }
}

/// User data manager with Reverse Mode support
@MainActor
class UserDataManager: ObservableObject {
    // MARK: - Basic Properties (Existing)
    @Published var username: String = ""
    @Published var isUsernameSet: Bool = false
    @Published var hasSeenTutorial: Bool = false
    @Published var isLoading: Bool = false
    @Published var connectionStatus: ConnectionStatus = .offline
    @Published var errorMessage: String = ""
    @Published var isNewUser: Bool = false
    @Published var isAppleSignInUser: Bool = false
    @Published var needsUsernameSetup: Bool = false
    
    // Core Statistics (Normal Mode)
    @Published var totalGamesPlayed: Int = 0
    @Published var bestScore: Int = 0
    @Published var bestStreak: Int = 0
    @Published var averageScore: Double = 0.0
    @Published var totalCorrectAnswers: Int = 0
    @Published var totalQuestions: Int = 0
    @Published var gameHistory: [GameSession] = []
    
    // Category Statistics (Normal Mode)
    @Published var categoryStats: [String: CategoryStats] = [:]
    @Published var achievements: Set<Achievement> = []
    
    // MARK: - Reverse Mode Properties (NEW)
    @Published var reverseModeEnabled: Bool = false {
        didSet {
            savePreferences()
        }
    }
    @Published var reverseModeTotalGames: Int = 0
    @Published var reverseModeBestScore: Int = 0
    @Published var reverseModeBestStreak: Int = 0
    @Published var reverseModeAverageScore: Double = 0.0
    @Published var reverseModeTotalCorrect: Int = 0
    @Published var reverseModeTotalQuestions: Int = 0
    @Published var reverseModeTotalXP: Int = 0
    @Published var reverseModeLevel: Int = 1
    @Published var reverseModeHistory: [ReverseModeSession] = []
    @Published var reverseModeCategoryStats: [String: CategoryStats] = [:]
    @Published var reverseModeAchievements: Set<ReverseModeAchievement> = []
    
    // User Preferences (NEW)
    @Published var soundEffectsEnabled: Bool = true
    @Published var hapticFeedbackEnabled: Bool = true
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let apiService = APIService()
    private let supabase = SupabaseClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var pendingGameSessions: [GameSession] = []
    private var pendingReverseModeSessions: [ReverseModeSession] = []
    
    enum ConnectionStatus {
        case online, offline, syncing
        
        var displayText: String {
            switch self {
            case .online: return "Online"
            case .offline: return "Offline"
            case .syncing: return "Syncing..."
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadUserData()
        loadPendingGameSessions()
        loadPreferences()
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        supabase.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                Task { @MainActor [weak self] in
                    if isAuthenticated {
                        await self?.handleUserSignedIn()
                    } else {
                        self?.handleUserSignedOut()
                    }
                }
            }
            .store(in: &cancellables)
        
        supabase.$user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                Task { @MainActor [weak self] in
                    if let user = user {
                        self?.username = user.userMetadata.username
                        self?.isUsernameSet = true
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func recordGameSession(score: Int, streak: Int, correctAnswers: Int, totalQuestions: Int, gameType: String) {
        guard score >= 0, streak >= 0, correctAnswers >= 0, totalQuestions > 0, correctAnswers <= totalQuestions else {
            return
        }
        
        let session = GameSession(
            username: username,  // Change from 'date:' to 'username:'
            score: score,
            streak: streak,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            gameType: gameType
        )
        
        // Update local statistics
        updateStatistics(with: session)
        gameHistory.append(session)
        checkForAchievements(session)
        saveUserData()
    }
    
    func categoryAccuracy(for category: String) -> Double {
        return categoryStats[category]?.accuracy ?? 0.0
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.signOut()
                clearLocalData()
            } catch {
                errorMessage = "Failed to sign out: \(error.localizedDescription)"
            }
        }
    }
    
    func resetTutorial() {
        hasSeenTutorial = false
        userDefaults.set(false, forKey: "hasSeenTutorial")
    }
    
    func completeTutorial() {
        hasSeenTutorial = true
        userDefaults.set(true, forKey: "hasSeenTutorial")
    }
    
    func checkAuthenticationStatus() {
        Task {
            // Check if user is authenticated using public properties
            if supabase.isAuthenticated {
                await handleUserSignedIn()
            } else {
                // Try to restore session if possible
                if let _ = supabase.user {
                    await handleUserSignedIn()
                }
            }
        }
    }
    
    func clearError() {
        errorMessage = ""
    }
    
    func signInWithApple() async throws {
        // This would be implemented with proper Apple Sign In
        // For now, just a placeholder
        throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign In not implemented"])
    }
    
    func createAccount(with username: String) async throws {
        self.username = username
        self.isUsernameSet = true
        saveUserData()
    }
    
    func updateUsername(_ newUsername: String) async throws {
        // Validate username
        guard newUsername.count >= 3, newUsername.count <= 20 else {
            throw NSError(domain: "UserDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Username must be 3-20 characters"])
        }
        
        // Update local
        self.username = newUsername
        saveUserData()
        
        // Update server if online
        if supabase.isAuthenticated {
            // API call would go here
        }
    }
    
    // MARK: - Reverse Mode Methods (NEW)
    
    func toggleReverseMode() {
        reverseModeEnabled.toggle()
        savePreferences()
        
        // Sync preferences to server if online
        if connectionStatus == .online {
            Task {
                await syncPreferencesToServer()
            }
        }
    }
    
    func recordReverseModeSession(score: Int, streak: Int, correctAnswers: Int, totalQuestions: Int, gameType: String, soundHintsUsed: Int = 0, theoryHintsUsed: Int = 0) {
        guard score >= 0, streak >= 0, correctAnswers >= 0, totalQuestions > 0, correctAnswers <= totalQuestions else {
            return
        }
        
        let session = ReverseModeSession(
            username: username,
            score: score,
            streak: streak,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            gameType: gameType,
            hintsUsed: soundHintsUsed + theoryHintsUsed,
            soundHintsUsed: soundHintsUsed,
            theoryHintsUsed: theoryHintsUsed
        )
        
        // Update local statistics
        updateReverseModeStatistics(with: session)
        reverseModeHistory.append(session)
        checkForReverseModeAchievements(session)
        saveUserData()
        
        // Submit to database
        if supabase.isAuthenticated && connectionStatus != .offline {
            Task {
                await submitReverseModeSessionToDatabase(session)
            }
        } else {
            pendingReverseModeSessions.append(session)
            savePendingReverseSessions()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateStatistics(with session: GameSession) {
        totalGamesPlayed += 1
        bestScore = max(bestScore, session.score)
        bestStreak = max(bestStreak, session.streak)
        totalCorrectAnswers += session.correctAnswers
        totalQuestions += session.totalQuestions
        
        let totalScore = gameHistory.reduce(session.score) { $0 + $1.score }
        averageScore = Double(totalScore) / Double(totalGamesPlayed)
        
        // Update category statistics
        var stats = categoryStats[session.gameType] ?? CategoryStats()
        stats.sessionsPlayed += 1
        stats.bestScore = max(stats.bestScore, session.score)
        stats.correctAnswers += session.correctAnswers
        stats.totalQuestions += session.totalQuestions
        stats.totalScore += session.score
        stats.averageScore = Double(stats.totalScore) / Double(stats.sessionsPlayed)
        categoryStats[session.gameType] = stats
    }
    
    private func updateReverseModeStatistics(with session: ReverseModeSession) {
        reverseModeTotalGames += 1
        reverseModeBestScore = max(reverseModeBestScore, session.score)
        reverseModeBestStreak = max(reverseModeBestStreak, session.streak)
        reverseModeTotalCorrect += session.correctAnswers
        reverseModeTotalQuestions += session.totalQuestions
        
        // Calculate XP
        let xpGained = session.score / 10 + session.streak * 5
        reverseModeTotalXP += xpGained
        reverseModeLevel = (reverseModeTotalXP / 1000) + 1
        
        // Update average score
        let totalScore = reverseModeHistory.reduce(session.score) { $0 + $1.score }
        reverseModeAverageScore = Double(totalScore) / Double(reverseModeTotalGames)
        
        // Update category statistics
        updateReverseModeCategoryStatistics(with: session)
    }
    
    private func updateReverseModeCategoryStatistics(with session: ReverseModeSession) {
        let category = getCategoryFromGameType(session.gameType)
        var stats = reverseModeCategoryStats[category] ?? CategoryStats()
        
        stats.sessionsPlayed += 1
        stats.bestScore = max(stats.bestScore, session.score)
        stats.correctAnswers += session.correctAnswers
        stats.totalQuestions += session.totalQuestions
        stats.totalScore += session.score
        stats.averageScore = Double(stats.totalScore) / Double(stats.sessionsPlayed)
        
        reverseModeCategoryStats[category] = stats
    }
    
    private func getCategoryFromGameType(_ gameType: String) -> String {
        switch gameType {
        case "reverseDailyChallenge", "reverseBasicPractice":
            return "reverseBasicChords"
        case "reversePowerPractice":
            return "reversePowerChords"
        case "reverseBarrePractice":
            return "reverseBarreChords"
        case "reverseBluesPractice":
            return "reverseBluesChords"
        case "reverseMixedPractice":
            return "reverseMixedPractice"
        default:
            return "reverseBasicChords"
        }
    }
    
    private func checkForAchievements(_ session: GameSession) {
        // Check for first game
        if totalGamesPlayed >= 1 && !achievements.contains(.firstGame) {
            achievements.insert(.firstGame)
        }
        
        // Check for perfect score
        if session.correctAnswers == session.totalQuestions && !achievements.contains(.perfectScore) {
            achievements.insert(.perfectScore)
        }
        
        // Check for streak master
        if session.streak >= 10 && !achievements.contains(.streakMaster) {
            achievements.insert(.streakMaster)
        }
        
        // Check for quick learner
        if totalGamesPlayed >= 5 && !achievements.contains(.quickLearner) {
            achievements.insert(.quickLearner)
        }
    }
    
    private func checkForReverseModeAchievements(_ session: ReverseModeSession) {
        var newAchievements: [ReverseModeAchievement] = []
        
        // First game achievement
        if reverseModeTotalGames >= 1 && !reverseModeAchievements.contains(.reverseFirstSteps) {
            reverseModeAchievements.insert(.reverseFirstSteps)
            newAchievements.append(.reverseFirstSteps)
        }
        
        // Streak achievement
        if session.streak >= 5 && !reverseModeAchievements.contains(.reverseStreakMaster) {
            reverseModeAchievements.insert(.reverseStreakMaster)
            newAchievements.append(.reverseStreakMaster)
        }
        
        // No hints achievement
        if session.hintsUsed == 0 && session.correctAnswers == session.totalQuestions && !reverseModeAchievements.contains(.reverseNoHints) {
            reverseModeAchievements.insert(.reverseNoHints)
            newAchievements.append(.reverseNoHints)
        }
        
        // Level achievements
        if reverseModeLevel >= 10 && !reverseModeAchievements.contains(.reverseLevel10) {
            reverseModeAchievements.insert(.reverseLevel10)
            newAchievements.append(.reverseLevel10)
        }
        
        if reverseModeLevel >= 25 && !reverseModeAchievements.contains(.reverseLevel25) {
            reverseModeAchievements.insert(.reverseLevel25)
            newAchievements.append(.reverseLevel25)
        }
        
        // Submit new achievements to server
        if !newAchievements.isEmpty {
            Task {
                for achievement in newAchievements {
                    try? await apiService.unlockReverseModeAchievement(achievement.rawValue)
                }
            }
        }
    }
    
    private func submitReverseModeSessionToDatabase(_ session: ReverseModeSession) async {
        do {
            connectionStatus = .syncing
            _ = try await apiService.submitReverseModeSession(session)
            connectionStatus = .online
            errorMessage = ""
        } catch {
            connectionStatus = .offline
            errorMessage = "Failed to save reverse mode data"
            
            if !pendingReverseModeSessions.contains(where: { $0.id == session.id }) {
                pendingReverseModeSessions.append(session)
                savePendingReverseSessions()
            }
        }
    }
    
    private func loadPreferences() {
        reverseModeEnabled = userDefaults.bool(forKey: "reverseModeEnabled")
        soundEffectsEnabled = userDefaults.bool(forKey: "soundEffectsEnabled")
        hapticFeedbackEnabled = userDefaults.bool(forKey: "hapticFeedbackEnabled")
        
        // Load reverse mode stats
        reverseModeTotalGames = userDefaults.integer(forKey: "reverseModeTotalGames")
        reverseModeBestScore = userDefaults.integer(forKey: "reverseModeBestScore")
        reverseModeBestStreak = userDefaults.integer(forKey: "reverseModeBestStreak")
        reverseModeAverageScore = userDefaults.double(forKey: "reverseModeAverageScore")
        reverseModeTotalCorrect = userDefaults.integer(forKey: "reverseModeTotalCorrect")
        reverseModeTotalQuestions = userDefaults.integer(forKey: "reverseModeTotalQuestions")
        reverseModeTotalXP = userDefaults.integer(forKey: "reverseModeTotalXP")
        reverseModeLevel = max(1, userDefaults.integer(forKey: "reverseModeLevel"))
        
        // Load reverse mode achievements
        if let achievementData = userDefaults.data(forKey: "reverseModeAchievements"),
           let achievementArray = try? JSONDecoder().decode([ReverseModeAchievement].self, from: achievementData) {
            reverseModeAchievements = Set(achievementArray)
        }
        
        // Load reverse mode history
        if let historyData = userDefaults.data(forKey: "reverseModeHistory"),
           let history = try? JSONDecoder().decode([ReverseModeSession].self, from: historyData) {
            reverseModeHistory = history
        }
        
        // Load reverse mode category stats
        if let categoryData = userDefaults.data(forKey: "reverseModeCategoryStats"),
           let stats = try? JSONDecoder().decode([String: CategoryStats].self, from: categoryData) {
            reverseModeCategoryStats = stats
        }
    }
    
    private func savePreferences() {
        userDefaults.set(reverseModeEnabled, forKey: "reverseModeEnabled")
        userDefaults.set(soundEffectsEnabled, forKey: "soundEffectsEnabled")
        userDefaults.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
    }
    
    private func syncPreferencesToServer() async {
        guard supabase.isAuthenticated else { return }
        
        let preferences = UserPreferences(
            reverseModeEnabled: reverseModeEnabled,
            preferredTheme: reverseModeEnabled ? "purple" : "green",
            soundEffectsEnabled: soundEffectsEnabled,
            hapticFeedbackEnabled: hapticFeedbackEnabled
        )
        
        do {
            try await apiService.updateUserPreferences(preferences)
        } catch {
            print("Failed to sync preferences: \(error)")
        }
    }
    
    private func loadUserData() {
        // Load normal mode data
        totalGamesPlayed = userDefaults.integer(forKey: "totalGamesPlayed")
        bestScore = userDefaults.integer(forKey: "bestScore")
        bestStreak = userDefaults.integer(forKey: "bestStreak")
        averageScore = userDefaults.double(forKey: "averageScore")
        totalCorrectAnswers = userDefaults.integer(forKey: "totalCorrectAnswers")
        totalQuestions = userDefaults.integer(forKey: "totalQuestions")
        isUsernameSet = userDefaults.bool(forKey: "isUsernameSet")
        username = userDefaults.string(forKey: "username") ?? ""
        hasSeenTutorial = userDefaults.bool(forKey: "hasSeenTutorial")
        needsUsernameSetup = userDefaults.bool(forKey: "needsUsernameSetup")
        isAppleSignInUser = userDefaults.bool(forKey: "isAppleSignInUser")
        
        // Load achievements
        if let achievementData = userDefaults.data(forKey: "achievements"),
           let achievementArray = try? JSONDecoder().decode([Achievement].self, from: achievementData) {
            achievements = Set(achievementArray)
        }
        
        // Load history
        if let data = userDefaults.data(forKey: "gameHistory"),
           let history = try? JSONDecoder().decode([GameSession].self, from: data) {
            gameHistory = history
        }
        
        // Load category stats
        if let data = userDefaults.data(forKey: "categoryStats"),
           let stats = try? JSONDecoder().decode([String: CategoryStats].self, from: data) {
            categoryStats = stats
        }
    }
    
    private func loadPendingGameSessions() {
        if let data = userDefaults.data(forKey: "pendingGameSessions"),
           let sessions = try? JSONDecoder().decode([GameSession].self, from: data) {
            pendingGameSessions = sessions
        }
        
        if let data = userDefaults.data(forKey: "pendingReverseModeSessions"),
           let sessions = try? JSONDecoder().decode([ReverseModeSession].self, from: data) {
            pendingReverseModeSessions = sessions
        }
    }
    
    private func saveUserData() {
        // Save normal mode data
        userDefaults.set(totalGamesPlayed, forKey: "totalGamesPlayed")
        userDefaults.set(bestScore, forKey: "bestScore")
        userDefaults.set(bestStreak, forKey: "bestStreak")
        userDefaults.set(averageScore, forKey: "averageScore")
        userDefaults.set(totalCorrectAnswers, forKey: "totalCorrectAnswers")
        userDefaults.set(totalQuestions, forKey: "totalQuestions")
        userDefaults.set(hasSeenTutorial, forKey: "hasSeenTutorial")
        userDefaults.set(needsUsernameSetup, forKey: "needsUsernameSetup")
        userDefaults.set(isAppleSignInUser, forKey: "isAppleSignInUser")
        userDefaults.set(isUsernameSet, forKey: "isUsernameSet")
        userDefaults.set(username, forKey: "username")
        
        // Save reverse mode data
        userDefaults.set(reverseModeTotalGames, forKey: "reverseModeTotalGames")
        userDefaults.set(reverseModeBestScore, forKey: "reverseModeBestScore")
        userDefaults.set(reverseModeBestStreak, forKey: "reverseModeBestStreak")
        userDefaults.set(reverseModeAverageScore, forKey: "reverseModeAverageScore")
        userDefaults.set(reverseModeTotalCorrect, forKey: "reverseModeTotalCorrect")
        userDefaults.set(reverseModeTotalQuestions, forKey: "reverseModeTotalQuestions")
        userDefaults.set(reverseModeTotalXP, forKey: "reverseModeTotalXP")
        userDefaults.set(reverseModeLevel, forKey: "reverseModeLevel")
        
        // Save achievements
        if let achievementData = try? JSONEncoder().encode(Array(achievements)) {
            userDefaults.set(achievementData, forKey: "achievements")
        }
        
        if let reverseModeAchievementData = try? JSONEncoder().encode(Array(reverseModeAchievements)) {
            userDefaults.set(reverseModeAchievementData, forKey: "reverseModeAchievements")
        }
        
        // Save history
        if let data = try? JSONEncoder().encode(gameHistory) {
            userDefaults.set(data, forKey: "gameHistory")
        }
        
        if let reverseModeData = try? JSONEncoder().encode(reverseModeHistory) {
            userDefaults.set(reverseModeData, forKey: "reverseModeHistory")
        }
        
        // Save category stats
        if let data = try? JSONEncoder().encode(categoryStats) {
            userDefaults.set(data, forKey: "categoryStats")
        }
        
        if let reverseModeStatsData = try? JSONEncoder().encode(reverseModeCategoryStats) {
            userDefaults.set(reverseModeStatsData, forKey: "reverseModeCategoryStats")
        }
    }
    
    private func savePendingReverseSessions() {
        if let data = try? JSONEncoder().encode(pendingReverseModeSessions) {
            userDefaults.set(data, forKey: "pendingReverseModeSessions")
        }
    }
    
    private func handleUserSignedIn() async {
        // Handle user sign in
        if let user = supabase.user {
            username = user.userMetadata.username
            isUsernameSet = true
            connectionStatus = .online
            
            // Sync pending sessions
            await syncPendingSessions()
        }
    }
    
    private func handleUserSignedOut() {
        connectionStatus = .offline
    }
    
    private func syncPendingSessions() async {
        // Sync pending reverse mode sessions
        for session in pendingReverseModeSessions {
            await submitReverseModeSessionToDatabase(session)
        }
        
        if pendingReverseModeSessions.isEmpty {
            userDefaults.removeObject(forKey: "pendingReverseModeSessions")
        }
    }
    
    private func clearLocalData() {
        // Clear all local data
        username = ""
        isUsernameSet = false
        totalGamesPlayed = 0
        bestScore = 0
        bestStreak = 0
        averageScore = 0.0
        totalCorrectAnswers = 0
        totalQuestions = 0
        gameHistory = []
        categoryStats = [:]
        achievements = []
        
        // Clear reverse mode data
        reverseModeTotalGames = 0
        reverseModeBestScore = 0
        reverseModeBestStreak = 0
        reverseModeAverageScore = 0.0
        reverseModeTotalCorrect = 0
        reverseModeTotalQuestions = 0
        reverseModeTotalXP = 0
        reverseModeLevel = 1
        reverseModeHistory = []
        reverseModeCategoryStats = [:]
        reverseModeAchievements = []
        
        // Clear UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        userDefaults.synchronize()
    }
    
    // MARK: - Computed Properties
    
    var overallAccuracy: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return Double(totalCorrectAnswers) / Double(totalQuestions) * 100
    }
    
    var reverseModeAccuracy: Double {
        guard reverseModeTotalQuestions > 0 else { return 0.0 }
        return Double(reverseModeTotalCorrect) / Double(reverseModeTotalQuestions) * 100
    }
    
    var currentLevel: Int {
        let calculatedLevel = currentXP / 1000
        return max(1, calculatedLevel + 1)
    }
    
    var currentXP: Int {
        let baseXP = totalGamesPlayed * 100
        let scoreBonus = bestScore
        return max(0, baseXP + scoreBonus)
    }
    
    var levelProgress: Double {
        let xpInCurrentLevel = currentXP % 1000
        return max(0.0, min(1.0, Double(xpInCurrentLevel) / 1000.0))
    }
    
    var reverseModeLevelProgress: Double {
        let xpInCurrentLevel = reverseModeTotalXP % 1000
        return max(0.0, min(1.0, Double(xpInCurrentLevel) / 1000.0))
    }
    
    var perfectRounds: Int {
        return gameHistory.filter { session in
            session.correctAnswers == session.totalQuestions && session.totalQuestions > 0
        }.count
    }
}
