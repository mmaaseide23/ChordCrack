import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var accountManager = AccountManagementService.shared
    @StateObject private var analyticsManager = FirebaseAnalyticsManager.shared

    @State private var showingPrivacySettings = false
    @State private var showingDataExport = false
    @State private var showingDeleteAccount = false
    @State private var showingAbout = false
    @State private var privacySettings = PrivacySettings.default
    @State private var exportedData = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // Offline mode state
    @State private var isDownloadingAudio = false
    @State private var downloadProgress = 0.0
    @State private var downloadCompleted = 0
    @State private var downloadTotal = 0
    @State private var cacheSize = AudioCacheManager.shared.cacheSizeString
    @State private var cachedCount = AudioCacheManager.shared.cachedFileCount
    @State private var isFullyCached = AudioCacheManager.shared.isFullyCached

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - General
                settingsSection(title: "General") {
                    SettingsRow(title: "About ChordCrack", icon: "info.circle") {
                        showingAbout = true
                    }
                    SettingsRow(title: "Reset Tutorial", icon: "arrow.clockwise") {
                        userDataManager.resetTutorial()
                        alertTitle = "Tutorial Reset"
                        alertMessage = "You'll see the tutorial again next time you launch the app."
                        showingAlert = true
                    }
                }

                // MARK: - Offline Mode
                settingsSection(title: "Offline Mode") {
                    offlineDownloadRow
                    offlineCacheInfoRow
                }

                // MARK: - Privacy & Data
                settingsSection(title: "Privacy & Data") {
                    SettingsToggleRow(
                        title: "Analytics",
                        icon: "chart.bar.fill",
                        isOn: Binding(
                            get: { analyticsManager.isAnalyticsEnabled },
                            set: { analyticsManager.setAnalyticsEnabled($0) }
                        )
                    )
                    SettingsRow(title: "Privacy Settings", icon: "hand.raised.fill") {
                        showingPrivacySettings = true
                    }
                    SettingsRow(title: "Export My Data", icon: "square.and.arrow.up") {
                        showingDataExport = true
                    }
                }

                // MARK: - Account
                settingsSection(title: "Account") {
                    SettingsRow(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right") {
                        userDataManager.signOut()
                        presentationMode.wrappedValue.dismiss()
                    }
                    SettingsRow(title: "Delete Account", icon: "trash.fill", isDestructive: true) {
                        showingDeleteAccount = true
                    }
                }

                // Connection status
                connectionStatusSection

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background)
        .onAppear { loadPrivacySettings() }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView(privacySettings: $privacySettings, accountManager: accountManager)
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView(exportedData: $exportedData, accountManager: accountManager)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Delete Account", isPresented: $showingDeleteAccount) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
    }

    // MARK: - Offline Mode Views

    private var offlineDownloadRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Image(systemName: isFullyCached ? "checkmark.icloud.fill" : "icloud.and.arrow.down.fill")
                    .foregroundColor(isFullyCached ? Color.green : ColorTheme.primaryGreen)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isFullyCached ? "All Audio Downloaded" : "Download for Offline")
                        .font(.system(size: 15))
                        .foregroundColor(ColorTheme.textPrimary)

                    Text(isFullyCached ? "All chords available offline" : "Download all chord audio for offline play")
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                }

                Spacer()

                if isDownloadingAudio {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !isFullyCached {
                    Button {
                        startOfflineDownload()
                    } label: {
                        Text("Download")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(ColorTheme.primaryGreen)
                            )
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)

            if isDownloadingAudio {
                VStack(spacing: 4) {
                    ProgressView(value: downloadProgress)
                        .tint(ColorTheme.primaryGreen)

                    Text("\(downloadCompleted)/\(downloadTotal) files")
                        .font(.system(size: 11))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private var offlineCacheInfoRow: some View {
        HStack(spacing: 16) {
            Image(systemName: "internaldrive.fill")
                .foregroundColor(ColorTheme.textSecondary)
                .frame(width: 20)

            Text("Cache: \(cacheSize) (\(cachedCount) files)")
                .font(.system(size: 14))
                .foregroundColor(ColorTheme.textSecondary)

            Spacer()

            if cachedCount > 0 {
                Button {
                    AudioCacheManager.shared.clearCache()
                    refreshCacheState()
                    alertTitle = "Cache Cleared"
                    alertMessage = "Audio cache has been cleared. Files will be re-downloaded when needed."
                    showingAlert = true
                } label: {
                    Text("Clear")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.error)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    private func startOfflineDownload() {
        isDownloadingAudio = true
        downloadCompleted = 0
        downloadTotal = AudioCacheManager.shared.uncachedFileNames().count

        Task {
            await AudioCacheManager.shared.downloadAllUncached { completed, total in
                downloadCompleted = completed
                downloadTotal = total
                downloadProgress = total > 0 ? Double(completed) / Double(total) : 0
            }
            await MainActor.run {
                isDownloadingAudio = false
                refreshCacheState()
            }
        }
    }

    private func refreshCacheState() {
        cacheSize = AudioCacheManager.shared.cacheSizeString
        cachedCount = AudioCacheManager.shared.cachedFileCount
        isFullyCached = AudioCacheManager.shared.isFullyCached
    }

    // MARK: - Section Builder

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 2) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.cardBackground)
            )
        }
    }

    // MARK: - Connection Status

    private var connectionStatusSection: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            Text(connectionStatusText)
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
            Spacer()
            if userDataManager.connectionStatus == .syncing || accountManager.isLoading {
                ProgressView().scaleEffect(0.8)
            }
        }
        .padding(.top, 8)
    }

    private var connectionStatusColor: Color {
        switch userDataManager.connectionStatus {
        case .online: return Color.green
        case .offline: return Color.red
        case .syncing: return Color.orange
        }
    }

    private var connectionStatusText: String {
        switch userDataManager.connectionStatus {
        case .online: return "Connected to server"
        case .offline: return "Offline — data saved locally"
        case .syncing: return "Syncing..."
        }
    }

    // MARK: - Actions

    private func loadPrivacySettings() {
        Task {
            let settings = await accountManager.loadPrivacySettings()
            await MainActor.run { privacySettings = settings }
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

// MARK: - Toggle Row

struct SettingsToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(ColorTheme.primaryGreen)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(ColorTheme.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(ColorTheme.primaryGreen)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}
