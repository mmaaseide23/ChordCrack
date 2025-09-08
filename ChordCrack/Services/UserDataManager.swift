import Foundation
import Combine
import SwiftUI

/// User data manager with proper Supabase authentication and thread safety
@MainActor
class UserDataManager: ObservableObject {
    @Published var username: String = ""
    @Published var isUsernameSet: Bool = false
    @Published var hasSeenTutorial: Bool = false
    @Published var isLoading: Bool = false
    @Published var connectionStatus: ConnectionStatus = .offline
    
    // Core Statistics
    @Published var totalGamesPlayed: Int = 0
    @Published var bestScore: Int = 0
    @Published var bestStreak: Int = 0
    @Published var averageScore: Double = 0.0
    @Published var totalCorrectAnswers: Int = 0
    @Published var totalQuestions: Int = 0
    @Published var gameHistory: [GameSession] = []
    
    // Category Statistics
    @Published var categoryStats: [String: CategoryStats] = [:]
    @Published var achievements: Set<Achievement> = []
    
    private let userDefaults = UserDefaults.standard
    private let apiService = APIService()
    private let supabase = SupabaseClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus {
        case online, offline, syncing
    }
    
    // MARK: - Initialization
    
    init() {
        setupAuthStateListener()
        loadUserData()
    }
    
    private func setupAuthStateListener() {
        // Listen to authentication changes from Supabase
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
    
    // MARK: - Authentication Methods
    
    func createAccount(email: String, password: String, username: String) async throws {
        isLoading = true
        connectionStatus = .syncing
        
        do {
            let finalUsername = try await apiService.createAccount(email: email, password: password, username: username)
            
            self.username = finalUsername
            self.isUsernameSet = true
            self.isLoading = false
            self.hasSeenTutorial = false  // ONLY set to false for NEW accounts
            self.connectionStatus = .online
            
        } catch {
            self.isLoading = false
            self.connectionStatus = .offline
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        connectionStatus = .syncing
        
        do {
            let userUsername = try await apiService.signIn(email: email, password: password)
            
            self.username = userUsername
            self.isUsernameSet = true
            self.isLoading = false
            self.connectionStatus = .online
            // DON'T change hasSeenTutorial - preserve whatever value it had
            // The loadUserData() in init already loaded the saved value
            
            // Load user's game data
            await refreshUserData()
            
        } catch {
            self.isLoading = false
            self.connectionStatus = .offline
            throw error
        }
    }
    
    func signOut() {
        Task {
            try? await supabase.signOut()
        }
        // The auth state listener will handle cleanup
    }
    
    func checkAuthenticationStatus() {
        // Authentication status is automatically managed by SupabaseClient
        if supabase.isAuthenticated {
            Task {
                await refreshUserData()
            }
        }
    }
    
    // MARK: - Auth State Handlers
    
    private func handleUserSignedIn() async {
        guard let user = supabase.user else { return }
        
        username = user.userMetadata.username
        isUsernameSet = true
        connectionStatus = .online
        
        // Don't change hasSeenTutorial here - keep the saved value
        // Only new accounts should reset this
        
        await refreshUserData()
        await loadAchievements()
    }
    
    private func handleUserSignedOut() {
        resetAllUserData()
    }
    
    // MARK: - Public Methods
    
    func completeTutorial() {
        hasSeenTutorial = true
        saveUserData()
        
        // Update tutorial status in database
        Task {
            // Note: You might want to add this to your database schema
            // For now, we'll just track it locally
        }
    }
    
    func recordGameSession(score: Int, streak: Int, correctAnswers: Int, totalQuestions: Int, gameType: String = "dailyChallenge") {
        let session = GameSession(
            username: username,
            score: score,
            streak: streak,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            gameType: gameType
        )
        
        gameHistory.append(session)
        updateStatistics(with: session)
        checkForAchievements(session)
        saveUserData()
        
        Task {
            await submitGameSession(session)
        }
    }
    
    // MARK: - Statistics Computation
    
    var overallAccuracy: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return Double(totalCorrectAnswers) / Double(totalQuestions) * 100
    }
    
    var currentLevel: Int {
        return max(1, currentXP / 1000)
    }
    
    var currentXP: Int {
        return totalGamesPlayed * 100 + bestScore // Simple XP calculation
    }
    
    var levelProgress: Double {
        let currentLevelXP = currentXP - (currentLevel * 1000)
        return Double(currentLevelXP) / 1000.0
    }
    
    func categoryAccuracy(for category: String) -> Double {
        guard let stats = categoryStats[category], stats.totalQuestions > 0 else { return 0.0 }
        return Double(stats.correctAnswers) / Double(stats.totalQuestions) * 100
    }
    
    // MARK: - Force Logout Method
    
    func forceLogout() {
        signOut()
    }
    
    // MARK: - Private Methods
    
    private func updateStatistics(with session: GameSession) {
        totalGamesPlayed += 1
        bestScore = max(bestScore, session.score)
        bestStreak = max(bestStreak, session.streak)
        totalCorrectAnswers += session.correctAnswers
        totalQuestions += session.totalQuestions
        
        // Calculate average score
        let totalScore = gameHistory.reduce(0) { $0 + $1.score }
        averageScore = Double(totalScore) / Double(gameHistory.count)
        
        // Update category statistics
        updateCategoryStatistics(with: session)
    }
    
    private func updateCategoryStatistics(with session: GameSession) {
        let category = session.gameType
        var stats = categoryStats[category] ?? CategoryStats()
        
        stats.sessionsPlayed += 1
        stats.bestScore = max(stats.bestScore, session.score)
        stats.correctAnswers += session.correctAnswers
        stats.totalQuestions += session.totalQuestions
        stats.totalScore += session.score
        stats.averageScore = Double(stats.totalScore) / Double(stats.sessionsPlayed)
        
        categoryStats[category] = stats
    }
    
    private func checkForAchievements(_ session: GameSession) {
        var newAchievements: [Achievement] = []
        
        // First Steps
        if totalGamesPlayed >= 1 && !achievements.contains(.firstSteps) {
            achievements.insert(.firstSteps)
            newAchievements.append(.firstSteps)
        }
        
        // Streak Master
        if session.streak >= 5 && !achievements.contains(.streakMaster) {
            achievements.insert(.streakMaster)
            newAchievements.append(.streakMaster)
        }
        
        // Perfect Round
        if session.correctAnswers == session.totalQuestions && session.totalQuestions >= 5 && !achievements.contains(.perfectRound) {
            achievements.insert(.perfectRound)
            newAchievements.append(.perfectRound)
        }
        
        // Power Player
        if categoryAccuracy(for: "powerChords") >= 90 && !achievements.contains(.powerPlayer) {
            achievements.insert(.powerPlayer)
            newAchievements.append(.powerPlayer)
        }
        
        // Sync new achievements to database
        Task {
            for achievement in newAchievements {
                try? await apiService.unlockAchievement(achievement.rawValue)
            }
        }
    }
    
    private func refreshUserData() async {
        connectionStatus = .syncing
        
        // Save the current tutorial state before refreshing
        let currentTutorialState = hasSeenTutorial
        
        do {
            let stats = try await apiService.getUserStats(username: username)
            
            self.totalGamesPlayed = stats.totalGames
            self.bestScore = stats.bestScore
            self.bestStreak = stats.bestStreak
            self.averageScore = stats.averageScore
            self.totalCorrectAnswers = stats.totalCorrect
            self.totalQuestions = stats.totalQuestions
            self.connectionStatus = .online
            
            // Preserve the tutorial state
            self.hasSeenTutorial = currentTutorialState
            
            self.saveUserData()
            
        } catch {
            self.connectionStatus = .offline
            print("Failed to refresh user data: \(error)")
        }
    }
    
    private func loadAchievements() async {
        do {
            let achievementIds = try await apiService.getUserAchievements()
            self.achievements = Set(achievementIds.compactMap { Achievement(rawValue: $0) })
        } catch {
            print("Failed to load achievements: \(error)")
        }
    }
    
    private func submitGameSession(_ session: GameSession) async {
        do {
            let _ = try await apiService.submitGameSession(session)
            self.connectionStatus = .online
        } catch {
            self.connectionStatus = .offline
            print("Failed to submit game session: \(error)")
        }
    }
    
    private func loadUserData() {
        hasSeenTutorial = userDefaults.bool(forKey: "hasSeenTutorial")
        totalGamesPlayed = userDefaults.integer(forKey: "totalGamesPlayed")
        bestScore = userDefaults.integer(forKey: "bestScore")
        bestStreak = userDefaults.integer(forKey: "bestStreak")
        averageScore = userDefaults.double(forKey: "averageScore")
        totalCorrectAnswers = userDefaults.integer(forKey: "totalCorrectAnswers")
        totalQuestions = userDefaults.integer(forKey: "totalQuestions")
        
        // Load complex data
        if let achievementData = userDefaults.data(forKey: "achievements"),
           let achievementArray = try? JSONDecoder().decode([Achievement].self, from: achievementData) {
            achievements = Set(achievementArray)
        }
        
        if let data = userDefaults.data(forKey: "gameHistory"),
           let history = try? JSONDecoder().decode([GameSession].self, from: data) {
            gameHistory = history
        }
        
        if let data = userDefaults.data(forKey: "categoryStats"),
           let stats = try? JSONDecoder().decode([String: CategoryStats].self, from: data) {
            categoryStats = stats
        }
    }
    
    private func saveUserData() {
        userDefaults.set(totalGamesPlayed, forKey: "totalGamesPlayed")
        userDefaults.set(bestScore, forKey: "bestScore")
        userDefaults.set(bestStreak, forKey: "bestStreak")
        userDefaults.set(averageScore, forKey: "averageScore")
        userDefaults.set(totalCorrectAnswers, forKey: "totalCorrectAnswers")
        userDefaults.set(totalQuestions, forKey: "totalQuestions")
        userDefaults.set(hasSeenTutorial, forKey: "hasSeenTutorial")
        
        // Save complex data
        if let achievementData = try? JSONEncoder().encode(Array(achievements)) {
            userDefaults.set(achievementData, forKey: "achievements")
        }
        
        if let data = try? JSONEncoder().encode(gameHistory) {
            userDefaults.set(data, forKey: "gameHistory")
        }
        
        if let data = try? JSONEncoder().encode(categoryStats) {
            userDefaults.set(data, forKey: "categoryStats")
        }
    }
    
    private func resetAllUserData() {
        username = ""
        isUsernameSet = false
        totalGamesPlayed = 0
        bestScore = 0
        bestStreak = 0
        averageScore = 0.0
        totalCorrectAnswers = 0
        totalQuestions = 0
        gameHistory = []
        achievements = []
        categoryStats = [:]
        hasSeenTutorial = false
        connectionStatus = .offline
        
        // Clear UserDefaults
        let keys = ["totalGamesPlayed", "bestScore", "bestStreak", "averageScore",
                   "totalCorrectAnswers", "totalQuestions", "gameHistory",
                   "achievements", "categoryStats", "hasSeenTutorial"]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
    }
}

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
        return Double(correctAnswers) / Double(totalQuestions) * 100
    }
}

enum Achievement: String, Codable, CaseIterable {
    case firstSteps = "first_steps"
    case streakMaster = "streak_master"
    case perfectRound = "perfect_round"
    case barreExpert = "barre_expert"
    case bluesScholar = "blues_scholar"
    case powerPlayer = "power_player"
    case chordWizard = "chord_wizard"
    case perfectPitch = "perfect_pitch"
    case speedDemon = "speed_demon"
    
    var title: String {
        switch self {
        case .firstSteps: return "First Steps"
        case .streakMaster: return "Streak Master"
        case .perfectRound: return "Perfect Round"
        case .barreExpert: return "Barre Expert"
        case .bluesScholar: return "Blues Scholar"
        case .powerPlayer: return "Power Player"
        case .chordWizard: return "Chord Wizard"
        case .perfectPitch: return "Perfect Pitch"
        case .speedDemon: return "Speed Demon"
        }
    }
    
    var description: String {
        switch self {
        case .firstSteps: return "Play your first game"
        case .streakMaster: return "Achieve a 5+ streak"
        case .perfectRound: return "Perfect game (5/5)"
        case .barreExpert: return "80%+ barre chord accuracy"
        case .bluesScholar: return "70%+ blues chord accuracy"
        case .powerPlayer: return "90%+ power chord accuracy"
        case .chordWizard: return "Mixed mode mastery"
        case .perfectPitch: return "95%+ overall accuracy"
        case .speedDemon: return "High average scores"
        }
    }
    
    var icon: String {
        switch self {
        case .firstSteps: return "music.note"
        case .streakMaster: return "flame"
        case .perfectRound: return "star.circle.fill"
        case .barreExpert: return "guitars"
        case .bluesScholar: return "music.quarternote.3"
        case .powerPlayer: return "bolt"
        case .chordWizard: return "wand.and.stars"
        case .perfectPitch: return "ear"
        case .speedDemon: return "timer"
        }
    }
    
    var color: Color {
        switch self {
        case .firstSteps: return ColorTheme.primaryGreen
        case .streakMaster: return Color.orange
        case .perfectRound: return Color.yellow
        case .barreExpert: return Color.purple
        case .bluesScholar: return Color.blue
        case .powerPlayer: return Color.orange
        case .chordWizard: return Color.purple
        case .perfectPitch: return ColorTheme.lightGreen
        case .speedDemon: return Color.cyan
        }
    }
}
