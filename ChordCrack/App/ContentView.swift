import SwiftUI
import FirebaseAnalytics

struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    @StateObject private var audioManager = AudioManager()
    @StateObject private var userDataManager = UserDataManager()
    @State private var showTutorial = false

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
        .preferredColorScheme(.dark)
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
