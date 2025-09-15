import Foundation
import Combine
import SwiftUI

/// User data manager with proper Supabase authentication and robust stats recording
@MainActor
class UserDataManager: ObservableObject {
    @Published var username: String = ""
    @Published var isUsernameSet: Bool = false
    @Published var hasSeenTutorial: Bool = false
    @Published var isLoading: Bool = false
    @Published var connectionStatus: ConnectionStatus = .offline
    @Published var errorMessage: String = ""
    @Published var isNewUser: Bool = false // Track if user just signed up
    @Published var isAppleSignInUser: Bool = false // Track if user signed up via Apple
    @Published var needsUsernameSetup: Bool = false // Track if Apple user needs username setup
    
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
    private var pendingGameSessions: [GameSession] = []
    
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
    
    // MARK: - Authentication Methods
    
    func createAccount(email: String, password: String, username: String) async throws {
        isLoading = true
        connectionStatus = .syncing
        errorMessage = ""
        isNewUser = true // Mark as new user
        isAppleSignInUser = false // Not an Apple sign-in user
        
        do {
            let finalUsername = try await apiService.createAccount(email: email, password: password, username: username)
            
            self.username = finalUsername
            self.isUsernameSet = true
            self.isLoading = false
            self.hasSeenTutorial = false // New users haven't seen tutorial
            self.connectionStatus = .online
            
            saveUserData()
            
        } catch {
            self.isLoading = false
            self.connectionStatus = .offline
            self.errorMessage = error.localizedDescription
            self.isNewUser = false
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        connectionStatus = .syncing
        errorMessage = ""
        isNewUser = false // Existing user
        isAppleSignInUser = false // Not an Apple sign-in user
        
        do {
            let userUsername = try await apiService.signIn(email: email, password: password)
            
            self.username = userUsername
            self.isUsernameSet = true
            self.isLoading = false
            self.connectionStatus = .online
            
            await refreshUserData()
            await syncPendingGameSessions()
            
        } catch {
            self.isLoading = false
            self.connectionStatus = .offline
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithApple() async throws {
        isLoading = true
        connectionStatus = .syncing
        errorMessage = ""
        
        do {
            let userUsername = try await apiService.signInWithApple()
            
            // For Apple Sign-In, check if this is a new user by seeing if they have any game data
            await refreshUserData()
            
            // If they have no games played and no tutorial seen, they're a new Apple user
            let isFirstTimeAppleUser = totalGamesPlayed == 0 && !hasSeenTutorial
            
            self.username = userUsername
            self.isUsernameSet = true
            self.isLoading = false
            self.connectionStatus = .online
            self.isNewUser = isFirstTimeAppleUser
            self.isAppleSignInUser = true
            
            // Check if the username is a generic one and needs customization
            let needsCustomUsername = userUsername == "Apple User" ||
                                     userUsername.hasPrefix("user_") ||
                                     userUsername.isEmpty
            
            if isFirstTimeAppleUser {
                // New Apple users haven't seen tutorial and might need username setup
                self.hasSeenTutorial = false
                self.needsUsernameSetup = needsCustomUsername
            } else {
                // Existing users might still need username setup if they have generic username
                self.needsUsernameSetup = needsCustomUsername
            }
            
            await syncPendingGameSessions()
            saveUserData()
            
        } catch {
            self.isLoading = false
            self.connectionStatus = .offline
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.signOut()
            } catch {
                self.handleUserSignedOut()
            }
        }
    }
    
    func checkAuthenticationStatus() {
        if supabase.isAuthenticated {
            Task {
                await refreshUserData()
            }
        }
    }
    
    // MARK: - Username Management
    
    func updateUsername(_ newUsername: String) async throws {
        guard isUsernameSet else {
            throw APIError.notAuthenticated
        }
        
        let trimmedUsername = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidUsername(trimmedUsername) else {
            throw APIError.invalidCredentials // You might want to create a more specific error
        }
        
        isLoading = true
        errorMessage = ""
        
        // Update local state first
        self.username = trimmedUsername
        self.needsUsernameSetup = false // Username is now set
        saveUserData()
        
        // Try to sync with server
        Task {
            do {
                // Refresh user data to ensure consistency with server
                await refreshUserData()
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                // Even if server sync fails, keep the local change
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Username updated locally. Server sync will retry automatically."
                }
            }
        }
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        return username.count >= 3 &&
               username.count <= 20 &&
               username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
    
    // MARK: - Auth State Handlers
    
    private func handleUserSignedIn() async {
        guard let user = supabase.user else { return }
        
        username = user.userMetadata.username
        isUsernameSet = true
        connectionStatus = .online
        errorMessage = ""
        
        await refreshUserData()
        await loadAchievements()
        await syncPendingGameSessions()
    }
    
    private func handleUserSignedOut() {
        resetAllUserData()
    }
    
    // MARK: - Game Session Recording
    
    func recordGameSession(score: Int, streak: Int, correctAnswers: Int, totalQuestions: Int, gameType: String = "dailyChallenge") {
        guard score >= 0, streak >= 0, correctAnswers >= 0, totalQuestions > 0, correctAnswers <= totalQuestions else {
            return
        }
        
        let session = GameSession(
            username: username,
            score: score,
            streak: streak,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            gameType: gameType
        )
        
        // Immediately update local statistics
        updateLocalStatistics(with: session)
        gameHistory.append(session)
        checkForAchievements(session)
        saveUserData()
        
        // Submit to database
        if supabase.isAuthenticated && connectionStatus != .offline {
            Task {
                await submitGameSessionToDatabase(session)
            }
        } else {
            pendingGameSessions.append(session)
            savePendingGameSessions()
        }
    }
    
    private func updateLocalStatistics(with session: GameSession) {
        totalGamesPlayed += 1
        bestScore = max(bestScore, session.score)
        bestStreak = max(bestStreak, session.streak)
        totalCorrectAnswers += session.correctAnswers
        totalQuestions += session.totalQuestions
        
        let totalScore = gameHistory.reduce(session.score) { $0 + $1.score }
        averageScore = Double(totalScore) / Double(totalGamesPlayed)
        
        updateCategoryStatistics(with: session)
    }
    
    private func submitGameSessionToDatabase(_ session: GameSession) async {
        do {
            connectionStatus = .syncing
            _ = try await apiService.submitGameSession(session)
            connectionStatus = .online
            errorMessage = ""
        } catch APIError.notAuthenticated {
            connectionStatus = .offline
            errorMessage = "Please sign in again"
            
            if !pendingGameSessions.contains(where: { $0.id == session.id }) {
                pendingGameSessions.append(session)
                savePendingGameSessions()
            }
        } catch {
            connectionStatus = .offline
            errorMessage = "Failed to save game data"
            
            if !pendingGameSessions.contains(where: { $0.id == session.id }) {
                pendingGameSessions.append(session)
                savePendingGameSessions()
            }
        }
    }
    
    // MARK: - Pending Sessions Management
    
    private func savePendingGameSessions() {
        if let data = try? JSONEncoder().encode(pendingGameSessions) {
            userDefaults.set(data, forKey: "pendingGameSessions")
        }
    }
    
    private func loadPendingGameSessions() {
        if let data = userDefaults.data(forKey: "pendingGameSessions"),
           let sessions = try? JSONDecoder().decode([GameSession].self, from: data) {
            pendingGameSessions = sessions
        }
    }
    
    private func syncPendingGameSessions() async {
        guard !pendingGameSessions.isEmpty, supabase.isAuthenticated else { return }
        
        var successfullySynced: [UUID] = []
        
        for session in pendingGameSessions {
            do {
                _ = try await apiService.submitGameSession(session)
                successfullySynced.append(session.id)
            } catch {
                // Keep session for retry later
            }
        }
        
        pendingGameSessions.removeAll { successfullySynced.contains($0.id) }
        savePendingGameSessions()
        
        if successfullySynced.count > 0 {
            await refreshUserData()
        }
    }
    
    // MARK: - Public Methods
    
    func completeTutorial() {
        hasSeenTutorial = true
        isNewUser = false // User is no longer new after seeing tutorial
        saveUserData()
    }
    
    func resetTutorial() {
        hasSeenTutorial = false
        saveUserData()
    }
    
    func clearError() {
        errorMessage = ""
    }
    
    // MARK: - Statistics Computation (FIXED XP CALCULATION)
    
    var overallAccuracy: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return Double(totalCorrectAnswers) / Double(totalQuestions) * 100
    }
    
    var currentLevel: Int {
        // Start at level 1, not 0
        let calculatedLevel = currentXP / 1000
        return max(1, calculatedLevel + 1)
    }
    
    var currentXP: Int {
        // Only count XP from completed games
        // Each completed game gives 100 XP plus bonus for score
        let baseXP = totalGamesPlayed * 100
        let scoreBonus = bestScore  // Best score as bonus XP
        return max(0, baseXP + scoreBonus)  // Ensure XP is never negative
    }
    
    var levelProgress: Double {
        let xpInCurrentLevel = currentXP % 1000
        return max(0.0, min(1.0, Double(xpInCurrentLevel) / 1000.0))
    }
    
    func categoryAccuracy(for category: String) -> Double {
        guard let stats = categoryStats[category], stats.totalQuestions > 0 else { return 0.0 }
        return Double(stats.correctAnswers) / Double(stats.totalQuestions) * 100
    }
    
    // MARK: - Private Methods
    
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
        
        if totalGamesPlayed >= 1 && !achievements.contains(.firstSteps) {
            achievements.insert(.firstSteps)
            newAchievements.append(.firstSteps)
        }
        
        if session.streak >= 5 && !achievements.contains(.streakMaster) {
            achievements.insert(.streakMaster)
            newAchievements.append(.streakMaster)
        }
        
        if session.correctAnswers == session.totalQuestions && session.totalQuestions >= 5 && !achievements.contains(.perfectRound) {
            achievements.insert(.perfectRound)
            newAchievements.append(.perfectRound)
        }
        
        if categoryAccuracy(for: "powerChords") >= 90 && !achievements.contains(.powerPlayer) {
            achievements.insert(.powerPlayer)
            newAchievements.append(.powerPlayer)
        }
        
        if overallAccuracy >= 95 && !achievements.contains(.perfectPitch) {
            achievements.insert(.perfectPitch)
            newAchievements.append(.perfectPitch)
        }
        
        if !newAchievements.isEmpty {
            Task {
                for achievement in newAchievements {
                    try? await apiService.unlockAchievement(achievement.rawValue)
                }
            }
        }
    }
    
    private func refreshUserData() async {
        connectionStatus = .syncing
        let currentTutorialState = hasSeenTutorial
        
        do {
            let stats = try await apiService.getUserStats(username: username)
            
            if stats.totalGames >= totalGamesPlayed {
                self.totalGamesPlayed = stats.totalGames
                self.bestScore = max(stats.bestScore, self.bestScore)
                self.bestStreak = max(stats.bestStreak, self.bestStreak)
                self.averageScore = stats.averageScore
                self.totalCorrectAnswers = stats.totalCorrect
                self.totalQuestions = stats.totalQuestions
            }
            
            self.connectionStatus = .online
            self.errorMessage = ""
            self.hasSeenTutorial = currentTutorialState
            
            saveUserData()
            
        } catch APIError.notAuthenticated {
            self.connectionStatus = .offline
            self.errorMessage = "Please sign in again"
            signOut()
        } catch {
            self.connectionStatus = .offline
            self.errorMessage = "Failed to sync data"
        }
    }
    
    private func loadAchievements() async {
        do {
            let achievementIds = try await apiService.getUserAchievements()
            achievements = Set(achievementIds.compactMap { Achievement(rawValue: $0) })
        } catch {
            // Silently fail for achievements
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
        needsUsernameSetup = userDefaults.bool(forKey: "needsUsernameSetup")
        isAppleSignInUser = userDefaults.bool(forKey: "isAppleSignInUser")
        
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
        userDefaults.set(needsUsernameSetup, forKey: "needsUsernameSetup")
        userDefaults.set(isAppleSignInUser, forKey: "isAppleSignInUser")
        
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
        errorMessage = ""
        pendingGameSessions = []
        isNewUser = false
        isAppleSignInUser = false
        
        let keys = ["totalGamesPlayed", "bestScore", "bestStreak", "averageScore",
                   "totalCorrectAnswers", "totalQuestions", "gameHistory",
                   "achievements", "categoryStats", "hasSeenTutorial", "pendingGameSessions",
                   "isAppleSignInUser"]
        
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
