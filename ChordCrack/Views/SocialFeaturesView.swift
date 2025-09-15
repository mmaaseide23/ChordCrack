import SwiftUI

/// Social features including leaderboards and friends - Connected to Supabase
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
            
            // Tab Selector - Only Leaderboard and Friends
            Picker("Social Tab", selection: $selectedTab) {
                Text("Leaderboard").tag(0)
                Text("Friends").tag(1)
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

// MARK: - Enhanced Friends View with Stats

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
                    // Friends list with enhanced stats
                    LazyVStack(spacing: 12) {
                        ForEach(socialManager.friends) { friend in
                            EnhancedFriendEntryView(friend: friend)
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
            
            Text("Add friends to compare stats and track progress together!")
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

// Enhanced Friend Entry with Full Stats Display
struct EnhancedFriendEntryView: View {
    let friend: SocialFriend
    @EnvironmentObject var socialManager: SocialManager
    @State private var showingRemoveConfirmation = false
    @State private var expanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 16) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(ColorTheme.primaryGreen)
                        .frame(width: 44, height: 44)
                    
                    Text(String(friend.username.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Circle()
                        .fill(friend.status.color)
                        .frame(width: 12, height: 12)
                        .offset(x: 16, y: -16)
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text(friend.statusText)
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    // View stats button
                    Button(action: { withAnimation { expanded.toggle() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: expanded ? "chevron.up" : "chart.bar.fill")
                                .font(.system(size: 12))
                            Text(expanded ? "Hide" : "Stats")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(ColorTheme.primaryGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ColorTheme.primaryGreen, lineWidth: 1)
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
            
            // Expanded stats section
            if expanded {
                VStack(spacing: 16) {
                    Divider()
                        .background(ColorTheme.textTertiary.opacity(0.2))
                    
                    // Stats grid
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            StatItem(
                                icon: "trophy.fill",
                                label: "Best Score",
                                value: "\(friend.bestScore)",
                                color: Color.yellow
                            )
                            
                            StatItem(
                                icon: "flame.fill",
                                label: "Best Streak",
                                value: "\(friend.bestStreak)",
                                color: Color.orange
                            )
                        }
                        
                        HStack(spacing: 16) {
                            StatItem(
                                icon: "gamecontroller.fill",
                                label: "Total Games",
                                value: "\(friend.totalGames)",
                                color: Color.blue
                            )
                            
                            StatItem(
                                icon: "target",
                                label: "Accuracy",
                                value: String(format: "%.0f%%", friend.accuracy),
                                color: ColorTheme.primaryGreen
                            )
                        }
                        
                        // Level indicator
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(Color.purple)
                                .font(.system(size: 14))
                            
                            Text("Level \(friend.level)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ColorTheme.textPrimary)
                            
                            Spacer()
                            
                            Text("\(friend.totalCorrect) correct answers")
                                .font(.system(size: 12))
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.purple.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(expanded ? ColorTheme.primaryGreen.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
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

// Stats item component
struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textSecondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.secondaryBackground)
        )
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
                    
                    Text("Enter your friend's username to send them a friend request")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
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
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
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

// MARK: - Friend Requests View (FIXED)

struct FriendRequestsView: View {
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                // Add background color to entire view to prevent black bars
                ColorTheme.background
                    .ignoresSafeArea()
                
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
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(ColorTheme.primaryGreen)
            )
        }
        // Fix navigation view style to prevent black bars
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Friend Request Entry View (FIXED)

struct FriendRequestEntryView: View {
    let request: FriendRequest
    @EnvironmentObject var socialManager: SocialManager
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {  // Reduced spacing to give more room
            // User avatar
            Circle()
                .fill(ColorTheme.primaryGreen)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(request.fromUsername.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Request info - flexible width
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromUsername)
                    .font(.system(size: 15, weight: .semibold))  // Slightly smaller font
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                
                Text("Sent \(request.timeAgo)")  // Shortened text
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Action buttons with fixed minimum width to prevent text wrapping
            if !isProcessing {
                HStack(spacing: 6) {  // Reduced spacing between buttons
                    Button(action: { respondToRequest(accept: true) }) {
                        Text("Accept")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(minWidth: 55)  // Fixed minimum width
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(ColorTheme.primaryGreen)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())  // Prevent default button styling
                    
                    Button(action: { respondToRequest(accept: false) }) {
                        Text("Decline")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ColorTheme.error)
                            .frame(minWidth: 55)  // Fixed minimum width
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(ColorTheme.error, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())  // Prevent default button styling
                }
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 120)  // Match combined button width
            }
        }
        .padding(14)  // Slightly reduced padding
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
