import SwiftUI

/// Social features including leaderboards and friend challenges - Connected to Supabase
struct SocialFeaturesView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @StateObject private var socialManager = SocialManager()
    @State private var selectedTab = 0
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Social Hub")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Spacer()
                
                Button(action: {
                    socialManager.clearError()
                    socialManager.refreshData()
                }) {
                    Image(systemName: socialManager.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                        .foregroundColor(ColorTheme.primaryGreen)
                        .font(.title3)
                        .rotationEffect(.degrees(socialManager.isLoading ? 360 : 0))
                        .animation(socialManager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: socialManager.isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Error Banner
            if !socialManager.errorMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text(socialManager.errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        socialManager.clearError()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ColorTheme.primaryGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            
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

// MARK: - Leaderboard View

struct LeaderboardView: View {
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Text("Global Leaderboard")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("Top players worldwide")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .padding(.top, 20)
                
                // Loading state
                if socialManager.isLoading && socialManager.leaderboardEntries.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading leaderboard...")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    .padding(.vertical, 40)
                } else if socialManager.leaderboardEntries.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "trophy")
                            .font(.system(size: 40))
                            .foregroundColor(ColorTheme.textTertiary)
                        
                        Text("No Leaderboard Data")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Text("Play more games to see rankings!")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                    .padding(.vertical, 40)
                } else {
                    // Leaderboard entries
                    LazyVStack(spacing: 12) {
                        ForEach(socialManager.leaderboardEntries) { entry in
                            LeaderboardEntryView(entry: entry)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 40)
            }
        }
        .refreshable {
            await socialManager.loadLeaderboard()
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
    @State private var showingFriendRequests = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with add friend button and requests indicator
                HStack {
                    Text("Your Friends")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Spacer()
                    
                    // Friend requests button with badge
                    Button(action: { showingFriendRequests = true }) {
                        ZStack {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .foregroundColor(ColorTheme.primaryGreen)
                                .font(.title3)
                            
                            if !socialManager.friendRequests.isEmpty {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Text("\(socialManager.friendRequests.count)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                    
                    Button(action: { showingAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(ColorTheme.primaryGreen)
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Loading or empty state
                if socialManager.isLoading && socialManager.friends.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading friends...")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    .padding(.vertical, 40)
                } else if socialManager.friends.isEmpty {
                    emptyFriendsView
                } else {
                    // Friends list
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
        .refreshable {
            await socialManager.loadFriends()
            await socialManager.loadFriendRequests()
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView()
                .environmentObject(socialManager)
        }
        .sheet(isPresented: $showingFriendRequests) {
            FriendRequestsView()
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
            
            Button("Add Your First Friend") {
                showingAddFriend = true
            }
            .buttonStyle(PrimaryGameButtonStyle(color: ColorTheme.primaryGreen))
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
}

struct FriendEntryView: View {
    let friend: SocialFriend
    @EnvironmentObject var socialManager: SocialManager
    @State private var showingChallengeOptions = false
    @State private var showingRemoveConfirmation = false
    
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
            
            // Action buttons
            HStack(spacing: 8) {
                // Challenge button
                Button(action: { showingChallengeOptions = true }) {
                    Text("Challenge")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ColorTheme.primaryGreen)
                        )
                }
                
                // Remove friend button
                Button(action: { showingRemoveConfirmation = true }) {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
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
                        Task {
                            _ = await socialManager.sendChallenge(to: friend, type: .dailyChallenge)
                        }
                    },
                    .default(Text("Speed Round")) {
                        Task {
                            _ = await socialManager.sendChallenge(to: friend, type: .speedRound)
                        }
                    },
                    .default(Text("Mixed Mode")) {
                        Task {
                            _ = await socialManager.sendChallenge(to: friend, type: .mixedMode)
                        }
                    },
                    .cancel()
                ]
            )
        }
        .alert("Remove Friend", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await socialManager.removeFriend(friend)
                }
            }
        } message: {
            Text("Are you sure you want to remove \(friend.username) from your friends list?")
        }
    }
}

// MARK: - Challenges View

struct ChallengesView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var userDataManager: UserDataManager
    
    private var pendingChallenges: [SocialChallenge] {
        socialManager.challenges.filter { $0.status == .pending }
    }
    
    private var activeChallenges: [SocialChallenge] {
        socialManager.challenges.filter { $0.status == .active }
    }
    
    private var completedChallenges: [SocialChallenge] {
        socialManager.challenges.filter { $0.status == .completed }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Challenges")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .padding(.top, 20)
                
                if socialManager.isLoading && socialManager.challenges.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Loading challenges...")
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    .padding(.vertical, 40)
                } else if socialManager.challenges.isEmpty {
                    emptyChallengesView
                } else {
                    VStack(spacing: 20) {
                        // Pending challenges
                        if !pendingChallenges.isEmpty {
                            challengeSection(title: "Pending", challenges: pendingChallenges, color: Color.orange)
                        }
                        
                        // Active challenges
                        if !activeChallenges.isEmpty {
                            challengeSection(title: "Active", challenges: activeChallenges, color: ColorTheme.primaryGreen)
                        }
                        
                        // Recent completed challenges
                        if !completedChallenges.isEmpty {
                            challengeSection(title: "Completed", challenges: Array(completedChallenges.prefix(5)), color: Color.blue)
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .refreshable {
            await socialManager.loadChallenges()
        }
    }
    
    private func challengeSection(title: String, challenges: [SocialChallenge], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Spacer()
                
                Text("\(challenges.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(challenges) { challenge in
                    ChallengeEntryView(challenge: challenge)
                        .environmentObject(socialManager)
                        .environmentObject(userDataManager)
                }
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
    let challenge: SocialChallenge
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var userDataManager: UserDataManager
    
    private var isCurrentUserOpponent: Bool {
        challenge.opponentId == SupabaseClient.shared.user?.id
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(challenge.challenger) vs \(challenge.opponent)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(challenge.type.displayName)
                            .font(.system(size: 14))
                            .foregroundColor(challenge.type.color)
                        
                        Text("•")
                            .foregroundColor(ColorTheme.textTertiary)
                        
                        Text(challenge.timeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)
                    }
                }
                
                Spacer()
                
                challengeStatusBadge
            }
            
            // Show scores for completed challenges
            if challenge.status == .completed {
                HStack {
                    scoreDisplay(
                        label: challenge.challenger,
                        score: challenge.challengerScore,
                        isWinner: challenge.challengerScore > challenge.opponentScore
                    )
                    
                    Spacer()
                    
                    Text("VS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ColorTheme.textTertiary)
                    
                    Spacer()
                    
                    scoreDisplay(
                        label: challenge.opponent,
                        score: challenge.opponentScore,
                        isWinner: challenge.opponentScore > challenge.challengerScore
                    )
                }
                .padding(.top, 8)
            }
            
            // Action buttons for pending challenges
            if challenge.status == .pending && isCurrentUserOpponent {
                HStack(spacing: 12) {
                    Button("Accept") {
                        Task {
                            await socialManager.respondToChallenge(challenge, accept: true)
                        }
                    }
                    .buttonStyle(PrimaryGameButtonStyle(color: ColorTheme.primaryGreen))
                    
                    Button("Decline") {
                        Task {
                            await socialManager.respondToChallenge(challenge, accept: false)
                        }
                    }
                    .buttonStyle(SecondaryGameButtonStyle())
                }
            }
            
            // Play button for active challenges where user hasn't completed
            if challenge.status == .active && !hasUserCompleted {
                Button(action: {
                    // For now, just navigate to regular game
                    // TODO: Set up challenge context in GameManager
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Play Challenge")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(challenge.type.color)
                    )
                }
                .buttonStyle(PlainButtonStyle())
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
    
    private var hasUserCompleted: Bool {
        if challenge.challengerId == SupabaseClient.shared.user?.id {
            return challenge.challengerCompleted
        } else {
            return challenge.opponentCompleted
        }
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
    
    private func scoreDisplay(label: String, score: Int, isWinner: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
            
            HStack(spacing: 4) {
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.yellow)
                }
                
                Text("\(score)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isWinner ? Color.yellow : ColorTheme.textPrimary)
            }
        }
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.presentationMode) var presentationMode
    @State private var friendUsername = ""
    @State private var isLoading = false
    
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
                    
                    Button(action: sendFriendRequest) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "person.badge.plus")
                                Text("Send Friend Request")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(friendUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                     ColorTheme.textTertiary : ColorTheme.primaryGreen)
                        )
                    }
                    .disabled(friendUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
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
    
    private func sendFriendRequest() {
        isLoading = true
        
        Task {
            let success = await socialManager.sendFriendRequest(to: friendUsername.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isLoading = false
                if success {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// MARK: - Friend Requests View

struct FriendRequestsView: View {
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if socialManager.friendRequests.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 40))
                                .foregroundColor(ColorTheme.textTertiary)
                            
                            Text("No Friend Requests")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(ColorTheme.textSecondary)
                            
                            Text("You'll see incoming friend requests here")
                                .font(.system(size: 14))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(socialManager.friendRequests) { request in
                                FriendRequestEntryView(request: request)
                                    .environmentObject(socialManager)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(ColorTheme.primaryGreen)
            )
            .background(ColorTheme.background)
        }
    }
}

struct FriendRequestEntryView: View {
    let request: FriendRequest
    @EnvironmentObject var socialManager: SocialManager
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 16) {
            // User avatar
            Circle()
                .fill(ColorTheme.primaryGreen)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(request.fromUsername.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Request info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromUsername)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text("Sent friend request \(request.timeAgo)")
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            
            Spacer()
            
            // Action buttons
            if !isProcessing {
                HStack(spacing: 8) {
                    Button("Accept") {
                        respondToRequest(accept: true)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ColorTheme.primaryGreen)
                    )
                    
                    Button("Decline") {
                        respondToRequest(accept: false)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ColorTheme.error)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(ColorTheme.error, lineWidth: 1)
                    )
                }
            } else {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
    
    private func respondToRequest(accept: Bool) {
        isProcessing = true
        
        Task {
            await socialManager.respondToFriendRequest(request, accept: accept)
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}
