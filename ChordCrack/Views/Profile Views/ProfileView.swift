import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var accountManager = AccountManagementService.shared
    @StateObject private var biometricManager = BiometricAuthManager()
    
    @State private var showingAccountSettings = false
    @State private var showingPrivacySettings = false
    @State private var showingDataExport = false
    @State private var showingDeleteAccount = false
    @State private var showingAbout = false
    @State private var showingUsernameEdit = false
    @State private var privacySettings = PrivacySettings.default
    @State private var exportedData = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 16) {
                    Circle()
                        .fill(ColorTheme.primaryGreen)
                        .frame(width: 90, height: 90)
                        .overlay(
                            Text(String(userDataManager.username.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: ColorTheme.primaryGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Text(userDataManager.username)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(ColorTheme.textPrimary)
                            
                            Button(action: { showingUsernameEdit = true }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundColor(ColorTheme.primaryGreen)
                            }
                        }
                        
                        // Dynamic title based on level
                        Text(getPlayerTitle())
                            .font(.system(size: 14))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    // Level and XP bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Level \(userDataManager.currentLevel)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ColorTheme.primaryGreen)
                            
                            Spacer()
                            
                            let currentLevelXP = userDataManager.currentXP % 1000
                            Text("\(currentLevelXP)/1000 XP")
                                .font(.system(size: 10))
                                .foregroundColor(ColorTheme.textTertiary)
                        }
                        
                        ProgressView(value: userDataManager.levelProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: ColorTheme.primaryGreen))
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)
                
                // Statistics Grid
                VStack(spacing: 16) {
                    Text("Your Statistics")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ProfileStatCard(
                            title: "Games",
                            value: "\(userDataManager.totalGamesPlayed)",
                            icon: "gamecontroller"
                        )
                        ProfileStatCard(
                            title: "Best Score",
                            value: "\(userDataManager.bestScore)",
                            icon: "star.fill"
                        )
                        ProfileStatCard(
                            title: "Best Streak",
                            value: "\(userDataManager.bestStreak)",
                            icon: "flame.fill"
                        )
                        ProfileStatCard(
                            title: "Accuracy",
                            value: String(format: "%.0f%%", userDataManager.overallAccuracy),
                            icon: "target"
                        )
                        ProfileStatCard(
                            title: "Avg Score",
                            value: String(format: "%.0f", userDataManager.averageScore),
                            icon: "chart.bar.fill"
                        )
                        ProfileStatCard(
                            title: "Correct",
                            value: "\(userDataManager.totalCorrectAnswers)",
                            icon: "checkmark.circle.fill"
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Achievements
                VStack(spacing: 16) {
                    Text("Achievements")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Achievement.allCases, id: \.rawValue) { achievement in
                            AchievementBadge(
                                title: achievement.title,
                                icon: achievement.icon,
                                isUnlocked: userDataManager.achievements.contains(achievement),
                                color: achievement.color
                            )
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Practice Progress
                VStack(spacing: 16) {
                    Text("Practice Progress")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        // Power Chords
                        PracticeProgressRow(
                            category: .power,
                            progress: userDataManager.categoryAccuracy(for: "powerChords") / 100,
                            completedSessions: userDataManager.categoryStats["powerChords"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "powerChords")
                        )
                        
                        // Barre Chords
                        PracticeProgressRow(
                            category: .barre,
                            progress: userDataManager.categoryAccuracy(for: "barreChords") / 100,
                            completedSessions: userDataManager.categoryStats["barreChords"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "barreChords")
                        )
                        
                        // Blues Chords
                        PracticeProgressRow(
                            category: .blues,
                            progress: userDataManager.categoryAccuracy(for: "bluesChords") / 100,
                            completedSessions: userDataManager.categoryStats["bluesChords"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "bluesChords")
                        )
                        
                        // Daily Challenge (Basic)
                        PracticeProgressRow(
                            category: .basic,
                            progress: userDataManager.categoryAccuracy(for: "dailyChallenge") / 100,
                            completedSessions: userDataManager.categoryStats["dailyChallenge"]?.sessionsPlayed ?? 0,
                            accuracy: userDataManager.categoryAccuracy(for: "dailyChallenge")
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Account Management Section
                VStack(spacing: 16) {
                    Text("Account Management")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        SettingsRow(title: "Privacy Settings", icon: "hand.raised.fill") {
                            showingPrivacySettings = true
                        }
                        
                        SettingsRow(title: "Security Settings", icon: "lock.fill") {
                            showingAccountSettings = true
                        }
                        
                        SettingsRow(title: "Export My Data", icon: "square.and.arrow.up") {
                            showingDataExport = true
                        }
                        
                        SettingsRow(title: "Delete Account", icon: "trash.fill", isDestructive: true) {
                            showingDeleteAccount = true
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Settings
                VStack(spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        SettingsRow(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right") {
                            userDataManager.signOut()
                            presentationMode.wrappedValue.dismiss()
                        }
                        
                        SettingsRow(title: "Reset Tutorial", icon: "arrow.clockwise") {
                            userDataManager.resetTutorial()
                            alertTitle = "Tutorial Reset"
                            alertMessage = "Tutorial has been reset. You'll see it again next time you launch the app."
                            showingAlert = true
                        }
                        
                        SettingsRow(title: "About ChordCrack", icon: "info.circle") {
                            showingAbout = true
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ColorTheme.cardBackground)
                )
                
                // Connection Status Indicator
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(connectionStatusText)
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        Spacer()
                        
                        if userDataManager.connectionStatus == .syncing || accountManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    // Show any error messages
                    if !userDataManager.errorMessage.isEmpty {
                        Text(userDataManager.errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                    
                    if !accountManager.errorMessage.isEmpty {
                        Text(accountManager.errorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding(.top, 8)
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background)
        .onAppear {
            loadPrivacySettings()
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView(
                privacySettings: $privacySettings,
                accountManager: accountManager
            )
        }
        .sheet(isPresented: $showingAccountSettings) {
            SecuritySettingsView(biometricManager: biometricManager)
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView(
                exportedData: $exportedData,
                accountManager: accountManager
            )
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingUsernameEdit) {
            UsernameEditView(userDataManager: userDataManager)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Delete Account", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }
    
    private func getPlayerTitle() -> String {
        let level = userDataManager.currentLevel
        switch level {
        case 1...5:
            return "Chord Beginner"
        case 6...10:
            return "Chord Student"
        case 11...20:
            return "Chord Apprentice"
        case 21...30:
            return "Chord Player"
        case 31...50:
            return "Chord Expert"
        case 51...75:
            return "Chord Master"
        case 76...99:
            return "Chord Virtuoso"
        default:
            return "Chord Legend"
        }
    }
    
    private var connectionStatusColor: Color {
        switch userDataManager.connectionStatus {
        case .online:
            return Color.green
        case .offline:
            return Color.red
        case .syncing:
            return Color.orange
        }
    }
    
    private var connectionStatusText: String {
        switch userDataManager.connectionStatus {
        case .online:
            return "Connected to server"
        case .offline:
            return "Offline - Data saved locally"
        case .syncing:
            return "Syncing..."
        }
    }
    
    private func loadPrivacySettings() {
        Task {
            privacySettings = await accountManager.loadPrivacySettings()
        }
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await accountManager.deleteAccount()
                await MainActor.run {
                    alertTitle = "Account Deleted"
                    alertMessage = "Your account has been successfully deleted."
                    showingAlert = true
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = "Failed to delete account: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Username Edit View

struct UsernameEditView: View {
    @ObservedObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var newUsername = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Edit Username")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Text("Choose a new username for your account. This will be visible to other players on leaderboards.")
                        .font(.system(size: 14))
                        .foregroundColor(ColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Username")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        HStack {
                            Text(userDataManager.username)
                                .font(.system(size: 16))
                                .foregroundColor(ColorTheme.textTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ColorTheme.secondaryBackground.opacity(0.5))
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Username")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        TextField("Enter new username", text: $newUsername)
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(ColorTheme.secondaryBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isValidNewUsername ? ColorTheme.primaryGreen.opacity(0.5) : ColorTheme.textTertiary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username Requirements:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ColorTheme.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            RequirementRow(text: "3-20 characters", isValid: newUsername.count >= 3 && newUsername.count <= 20)
                            RequirementRow(text: "Letters, numbers, - or _ only", isValid: isValidCharacters)
                            RequirementRow(text: "Different from current", isValid: newUsername != userDataManager.username && !newUsername.isEmpty)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Spacer()
                
                Button(action: updateUsername) {
                    HStack {
                        if userDataManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(userDataManager.isLoading ? "Updating..." : "Update Username")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canUpdate ? ColorTheme.primaryGreen : ColorTheme.textTertiary.opacity(0.5))
                    )
                }
                .disabled(!canUpdate)
                
                if !userDataManager.errorMessage.isEmpty {
                    Text(userDataManager.errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .background(ColorTheme.background)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: EmptyView()
            )
        }
        .onAppear {
            newUsername = userDataManager.username
            userDataManager.clearError()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Username Updated"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private var isValidNewUsername: Bool {
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 &&
               trimmed.count <= 20 &&
               isValidCharacters &&
               trimmed != userDataManager.username
    }
    
    private var isValidCharacters: Bool {
        !newUsername.isEmpty && newUsername.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
    
    private var canUpdate: Bool {
        isValidNewUsername && !userDataManager.isLoading
    }
    
    private func updateUsername() {
        let trimmedUsername = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                try await userDataManager.updateUsername(trimmedUsername)
                await MainActor.run {
                    alertMessage = "Your username has been successfully updated to \(trimmedUsername)."
                    showingAlert = true
                }
            } catch {
                // Error is already handled in UserDataManager
            }
        }
    }
}

struct RequirementRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(isValid ? ColorTheme.primaryGreen : ColorTheme.textTertiary.opacity(0.5))
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(isValid ? ColorTheme.textSecondary : ColorTheme.textTertiary.opacity(0.7))
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Title
                    VStack(spacing: 16) {
                        Circle()
                            .fill(ColorTheme.primaryGreen)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "guitars.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            )
                        
                        Text("ChordCrack")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                        
                        Text("Version 1.0.0")
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    // Description
                    VStack(spacing: 16) {
                        Text("About ChordCrack")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                        
                        Text("ChordCrack is designed to help guitarists develop their ear training skills by identifying chords by sound alone. Practice with different chord types, track your progress, and improve your musical ear through progressive hints and challenges.")
                            .font(.system(size: 16))
                            .foregroundColor(ColorTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal)
                    
                    // Features
                    VStack(spacing: 12) {
                        Text("Features")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ColorTheme.textPrimary)
                        
                        VStack(spacing: 8) {
                            FeatureRow(icon: "calendar", title: "Daily Challenges", description: "Practice with basic chords daily")
                            FeatureRow(icon: "guitars", title: "Multiple Chord Types", description: "Power, Barre, Blues, and Mixed modes")
                            FeatureRow(icon: "ear", title: "Progressive Hints", description: "Get help when you need it")
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Monitor your improvement over time")
                            FeatureRow(icon: "trophy", title: "Achievements", description: "Unlock rewards as you improve")
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(ColorTheme.background)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(ColorTheme.primaryGreen)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @Binding var privacySettings: PrivacySettings
    @ObservedObject var accountManager: AccountManagementService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Data Sharing")) {
                    Toggle("Share Statistics", isOn: $privacySettings.shareStats)
                    Toggle("Show on Leaderboard", isOn: $privacySettings.showOnLeaderboard)
                    Toggle("Allow Friend Requests", isOn: $privacySettings.allowFriendRequests)
                }
                
                Section(header: Text("Consent")) {
                    Toggle("Data Processing Consent", isOn: $privacySettings.dataProcessingConsent)
                    Toggle("Marketing Emails", isOn: $privacySettings.marketingEmails)
                }
                
                Section(footer: Text("Changes are automatically saved to your account.")) {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .disabled(accountManager.isLoading)
                }
                
                if accountManager.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Saving...")
                        }
                    }
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Privacy Settings"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func saveSettings() {
        Task {
            do {
                try await accountManager.updatePrivacySettings(privacySettings)
                await MainActor.run {
                    alertMessage = "Privacy settings saved successfully."
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to save privacy settings: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Security Settings View

struct SecuritySettingsView: View {
    @ObservedObject var biometricManager: BiometricAuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Biometric Authentication")) {
                    HStack {
                        Image(systemName: biometricManager.biometricType.icon)
                            .foregroundColor(ColorTheme.primaryGreen)
                        
                        VStack(alignment: .leading) {
                            Text(biometricManager.biometricType.displayName)
                            if biometricManager.biometricType != .none {
                                Text("Available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if biometricManager.biometricType != .none {
                            Toggle("", isOn: Binding(
                                get: { biometricManager.isEnabled },
                                set: { newValue in
                                    if newValue {
                                        enableBiometric()
                                    } else {
                                        biometricManager.disableBiometricAuth()
                                    }
                                }
                            ))
                        }
                    }
                }
                
                if biometricManager.biometricType == .none {
                    Section {
                        Text("Biometric authentication is not available on this device.")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Account Security")) {
                    Button("Change Password") {
                        // This would need to be implemented with Supabase auth
                        alertTitle = "Feature Coming Soon"
                        alertMessage = "Password change functionality will be available in a future update."
                        showingAlert = true
                    }
                }
            }
            .navigationTitle("Security Settings")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func enableBiometric() {
        Task {
            do {
                try await biometricManager.enableBiometricAuth()
            } catch {
                await MainActor.run {
                    alertTitle = "Authentication Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                    // Reset the toggle state since authentication failed
                    biometricManager.isEnabled = false
                }
            }
        }
    }
}

// MARK: - Data Export View

struct DataExportView: View {
    @Binding var exportedData: String
    @ObservedObject var accountManager: AccountManagementService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showingShareSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Your Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Download a copy of all your ChordCrack data including game statistics, achievements, and account information.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                if accountManager.isLoading {
                    ProgressView("Preparing your data...")
                        .padding()
                } else if !exportedData.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Your data is ready!")
                            .font(.headline)
                        
                        Button("Share Data Export") {
                            showingShareSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ColorTheme.primaryGreen)
                    }
                } else {
                    Button("Export My Data") {
                        exportData()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorTheme.primaryGreen)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Data Export")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if !exportedData.isEmpty {
                ShareSheet(activityItems: [exportedData])
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Data Export"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func exportData() {
        Task {
            do {
                let data = try await accountManager.exportUserData()
                await MainActor.run {
                    exportedData = data
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to export data: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Supporting Views

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ColorTheme.primaryGreen)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.secondaryBackground)
        )
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    let isUnlocked: Bool
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isUnlocked ? color : ColorTheme.textSecondary.opacity(0.5))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 85, height: 75)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isUnlocked ? color.opacity(0.15) : ColorTheme.secondaryBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnlocked ? color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(isUnlocked ? 1.0 : 0.95)
    }
}

struct PracticeProgressRow: View {
    let category: ChordCategory
    let progress: Double
    let completedSessions: Int
    let accuracy: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 20))
                .foregroundColor(category.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", accuracy))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(category.color)
                }
                
                Text("\(completedSessions) sessions completed")
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textSecondary)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: category.color))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTheme.secondaryBackground)
        )
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? Color.red : ColorTheme.primaryGreen)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(isDestructive ? Color.red : ColorTheme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(ColorTheme.textSecondary)
                    .font(.system(size: 12))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ColorTheme.secondaryBackground)
            )
        }
    }
}

// Note: ChordCategory and StatCard should be defined elsewhere in the project to avoid conflicts

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(UserDataManager())
            .environmentObject(GameManager())
    }
}
