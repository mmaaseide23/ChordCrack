import SwiftUI
import FirebaseAnalytics

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var userDataManager = UserDataManager()
    @State private var showTutorial = false
    @State private var showPracticePrototype = DesignDemo.isEnabled && ProcessInfo.processInfo.arguments.contains("--practice-prototype")

    private let analytics = FirebaseAnalyticsManager.shared

    var body: some View {
        NavigationStack {
            if !userDataManager.isUsernameSet {
                UsernameSetupView()
                    .environmentObject(userDataManager)
            } else {
                HomeView()
                    .environmentObject(gameManager)
                    .environmentObject(audioManager)
                    .environmentObject(userDataManager)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if DesignDemo.isEnabled {
                VStack(spacing: 0) {
                    Button("Try five-round practice") { showPracticePrototype = true }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("prototype.open")
                    Text("Design preview · Fictional progress · Synthesized audio")
                        .font(.caption2)
                        .foregroundStyle(ColorTheme.textSecondary)
                        .accessibilityIdentifier("design-preview-banner")
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(maxWidth: .infinity).padding(.bottom, 5)
                .background(ColorTheme.background)
            }
        }
        .preferredColorScheme(.dark)
        .tint(ColorTheme.primaryGreen)
        .onAppear {
            setupInitialState()
            analytics.trackScreenView("home")
        }
        .onChange(of: userDataManager.isUsernameSet) { oldValue, newValue in
            if !oldValue && newValue && userDataManager.isNewUser && !userDataManager.hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTutorial = true
                }
            }
        }
        .onChange(of: userDataManager.hasSeenTutorial) { oldValue, newValue in
            if oldValue && !newValue && userDataManager.isUsernameSet {
                showTutorial = true
            }
        }
        .fullScreenCover(isPresented: $showPracticePrototype) {
            FiveRoundPracticeView()
        }
        .fullScreenCover(isPresented: $showTutorial) {
            WelcomeTutorialView(showTutorial: $showTutorial)
                .onAppear {
                    analytics.trackTutorialStart()
                }
                .onDisappear {
                    if !userDataManager.hasSeenTutorial {
                        userDataManager.completeTutorial()
                    }
                }
        }
    }

    private func setupInitialState() {
        gameManager.setUserDataManager(userDataManager)
        gameManager.setAudioManager(audioManager)
        userDataManager.checkAuthenticationStatus()
    }
}

#Preview {
    ContentView()
}
