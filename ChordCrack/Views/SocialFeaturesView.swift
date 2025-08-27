import SwiftUI

/// Social features including leaderboards and friend challenges
struct SocialFeaturesView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @StateObject private var socialManager = SocialManager()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Social Hub")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Button(action: { socialManager.refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(ColorTheme.primaryGreen)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Tab Selector
            Picker("Social Tab", selection: $selectedTab) {
                Text("Leaderboard").tag(0)
                Text("Friends").tag(1)
                Text("Challenges").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Content
            TabView(selection: $selectedTab) {
                LeaderboardView()
                    .environmentObject(socialManager)
                    .tag(0)
                
                FriendsView()
                    .environmentObject(socialManager)
                    .environmentObject(userDataManager)
                    .tag(1)
                
                ChallengesView()
                    .environmentObject(socialManager)
                    .environmentObject(userDataManager)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .onAppear {
            socialManager.loadSocialData()
        }
    }
}

// MARK: - Social Manager

class SocialManager: ObservableObject {
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var friends: [Friend] = []
    @Published var activeChallenges: [Challenge] = []
    @Published var isLoading = false
    
    func loadSocialData() {
        isLoading = true
        
        // Simulate API calls - replace with actual backend calls
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.generateMockData()
            self.isLoading = false
        }
    }
    
    func refreshData() {
        loadSocialData()
    }
    
    func sendChallenge(to friend: Friend, type: ChallengeType) {
        let newChallenge = Challenge(
            id: UUID().uuidString,
            challenger: "You",
            opponent: friend.username,
            type: type,
            status: .pending,
            createdAt: Date()
        )
        
        activeChallenges.append(newChallenge)
    }
    
    private func generateMockData() {
        // Mock leaderboard data - Updated to match APIService LeaderboardEntry structure
        leaderboardEntries = [
            LeaderboardEntry(rank: 1, username: "GuitarHero92", bestScore: 2450, totalGames: 15),
            LeaderboardEntry(rank: 2, username: "ChordMaster", bestScore: 2380, totalGames: 12),
            LeaderboardEntry(rank: 3, username: "EarTrainer", bestScore: 2290, totalGames: 8),
            LeaderboardEntry(rank: 4, username: "MusicalMind", bestScore: 2180, totalGames: 10),
            LeaderboardEntry(rank: 5, username: "RockStar88", bestScore: 2050, totalGames: 6),
            LeaderboardEntry(rank: 6, username: "BluesLover", bestScore: 1980, totalGames: 7),
            LeaderboardEntry(rank: 7, username: "JazzCat", bestScore: 1920, totalGames: 5),
            LeaderboardEntry(rank: 8, username: "AcousticAce", bestScore: 1850, totalGames: 9)
        ]
        
        // Mock friends data
        friends = [
            Friend(username: "GuitarBuddy", status: .online, lastSeen: Date(), bestScore: 1890),
            Friend(username: "RiffMaster", status: .offline, lastSeen: Date().addingTimeInterval(-3600), bestScore: 1650),
            Friend(username: "ChordNinja", status: .playing, lastSeen: Date(), bestScore: 2100),
            Friend(username: "StrumKing", status: .offline, lastSeen: Date().addingTimeInterval(-7200), bestScore: 1420)
        ]
        
        // Mock challenges
        activeChallenges = [
            Challenge(id: "1", challenger: "GuitarBuddy", opponent: "You", type: .dailyChallenge, status: .pending, createdAt: Date().addingTimeInterval(-1800)),
            Challenge(id: "2", challenger: "You", opponent: "ChordNinja", type: .speedRound, status: .active, createdAt: Date().addingTimeInterval(-3600))
        ]
    }
}

// MARK: - Leaderboard View

struct LeaderboardView: View {
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Text("Daily Leaderboard")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("Top players worldwide")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .padding(.top, 20)
                
                // Leaderboard entries
                LazyVStack(spacing: 12) {
                    ForEach($socialManager.leaderboardEntries) { entry in
                        LeaderboardEntryView(entry: entry.wrappedValue)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
        }
    }
}

struct LeaderboardEntryView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 32, height: 32)
                
                Text("\(entry.rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                HStack(spacing: 12) {
                    Text("Best Score: \(entry.bestScore)")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                    
                    Text("Games: \(entry.totalGames)")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Trophy for top 3
            if entry.rank <= 3 {
                Image(systemName: "trophy.fill")
                    .foregroundColor(rankColor)
                    .font(.title3)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(entry.rank <= 3 ? rankColor.opacity(0.1) : ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(entry.rank <= 3 ? rankColor.opacity(0.3) : ColorTheme.textTertiary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return ColorTheme.primaryGreen
        }
    }
}

// MARK: - Friends View

struct FriendsView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var userDataManager: UserDataManager
    @State private var showingAddFriend = false
    @State private var friendUsername = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with add friend button
                HStack {
                    Text("Your Friends")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { showingAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(ColorTheme.primaryGreen)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Friends list
                if socialManager.friends.isEmpty {
                    emptyFriendsView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(socialManager.friends) { friend in
                            FriendEntryView(friend: friend)
                                .environmentObject(socialManager)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(friendUsername: $friendUsername)
                .environmentObject(socialManager)
        }
    }
    
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundColor(ColorTheme.textTertiary)
            
            Text("No Friends Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTheme.textSecondary)
            
            Text("Add friends to challenge them and compare your chord recognition skills!")
                .font(.system(size: 14))
                .foregroundColor(ColorTheme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
}

struct FriendEntryView: View {
    let friend: Friend
    @EnvironmentObject var socialManager: SocialManager
    @State private var showingChallengeOptions = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(ColorTheme.primaryGreen)
                    .frame(width: 40, height: 40)
                
                Text(String(friend.username.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Circle()
                    .fill(friend.status.color)
                    .frame(width: 12, height: 12)
                    .offset(x: 15, y: -15)
            }
            
            // Friend info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text(friend.statusText)
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
                
                Text("Best: \(friend.bestScore)")
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textTertiary)
            }
            
            Spacer()
            
            // Challenge button
            Button(action: { showingChallengeOptions = true }) {
                Text("Challenge")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(ColorTheme.primaryGreen)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
        .actionSheet(isPresented: $showingChallengeOptions) {
            ActionSheet(
                title: Text("Challenge \(friend.username)"),
                buttons: [
                    .default(Text("Daily Challenge")) {
                        socialManager.sendChallenge(to: friend, type: .dailyChallenge)
                    },
                    .default(Text("Speed Round")) {
                        socialManager.sendChallenge(to: friend, type: .speedRound)
                    },
                    .default(Text("Mixed Mode")) {
                        socialManager.sendChallenge(to: friend, type: .mixedMode)
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Challenges View

struct ChallengesView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var userDataManager: UserDataManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Active Challenges")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .padding(.top, 20)
                
                if socialManager.activeChallenges.isEmpty {
                    emptyChallengesView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(socialManager.activeChallenges) { challenge in
                            ChallengeEntryView(challenge: challenge)
                                .environmentObject(socialManager)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 40)
            }
        }
    }
    
    private var emptyChallengesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundColor(ColorTheme.textTertiary)
            
            Text("No Active Challenges")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ColorTheme.textSecondary)
            
            Text("Challenge your friends to chord recognition battles!")
                .font(.system(size: 14))
                .foregroundColor(ColorTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

struct ChallengeEntryView: View {
    let challenge: Challenge
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(challenge.challenger) vs \(challenge.opponent)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text(challenge.type.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(challenge.type.color)
                    
                    Text(challenge.timeAgo)
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textTertiary)
                }
                
                Spacer()
                
                challengeStatusBadge
            }
            
            if challenge.status == .pending && challenge.opponent == "You" {
                HStack(spacing: 12) {
                    Button("Accept") {
                        // Handle challenge acceptance
                    }
                    .buttonStyle(PrimaryButtonStyle(color: ColorTheme.primaryGreen))
                    
                    Button("Decline") {
                        // Handle challenge decline
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(challenge.type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var challengeStatusBadge: some View {
        Text(challenge.status.rawValue.capitalized)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(challenge.status.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(challenge.status.backgroundColor)
            )
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @Binding var friendUsername: String
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(ColorTheme.primaryGreen)
                    
                    Text("Add Friend")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    TextField("Enter username", text: $friendUsername)
                        .font(.system(size: 16))
                        .foregroundColor(ColorTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ColorTheme.secondaryBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(ColorTheme.textTertiary.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    Button("Send Friend Request") {
                        // Handle friend request
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: ColorTheme.primaryGreen))
                    .disabled(friendUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(ColorTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(ColorTheme.textSecondary)
            )
        }
    }
}

// MARK: - Data Models

struct Friend: Identifiable {
    let id = UUID()
    let username: String
    let status: UserStatus
    let lastSeen: Date
    let bestScore: Int
    
    var statusText: String {
        switch status {
        case .online: return "Online now"
        case .offline: return "Last seen \(timeAgo)"
        case .playing: return "Playing now"
        }
    }
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(lastSeen)
        let hours = Int(interval / 3600)
        if hours < 1 {
            return "recently"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            return "\(hours/24)d ago"
        }
    }
}

enum UserStatus {
    case online
    case offline
    case playing
    
    var color: Color {
        switch self {
        case .online: return Color.green
        case .offline: return Color.gray
        case .playing: return Color.orange
        }
    }
}

struct Challenge: Identifiable {
    let id: String
    let challenger: String
    let opponent: String
    let type: ChallengeType
    let status: ChallengeStatus
    let createdAt: Date
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            return "\(minutes/60)h ago"
        }
    }
}

enum ChallengeType: CaseIterable {
    case dailyChallenge
    case speedRound
    case mixedMode
    case chordProgression
    
    var displayName: String {
        switch self {
        case .dailyChallenge: return "Daily Challenge"
        case .speedRound: return "Speed Round"
        case .mixedMode: return "Mixed Mode"
        case .chordProgression: return "Chord Progression"
        }
    }
    
    var color: Color {
        switch self {
        case .dailyChallenge: return ColorTheme.primaryGreen
        case .speedRound: return Color.orange
        case .mixedMode: return Color.purple
        case .chordProgression: return Color.blue
        }
    }
}

enum ChallengeStatus: String {
    case pending = "pending"
    case active = "active"
    case completed = "completed"
    case declined = "declined"
    
    var backgroundColor: Color {
        switch self {
        case .pending: return Color.orange.opacity(0.2)
        case .active: return ColorTheme.primaryGreen.opacity(0.2)
        case .completed: return Color.blue.opacity(0.2)
        case .declined: return ColorTheme.error.opacity(0.2)
        }
    }
    
    var textColor: Color {
        switch self {
        case .pending: return Color.orange
        case .active: return ColorTheme.primaryGreen
        case .completed: return Color.blue
        case .declined: return ColorTheme.error
        }
    }
}
