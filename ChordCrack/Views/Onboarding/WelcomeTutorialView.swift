import SwiftUI

/// Welcome tutorial explaining how ChordCrack works for new users
struct WelcomeTutorialView: View {
    @Binding var showTutorial: Bool
    @State private var currentPage = 0
    
    private let tutorialPages = [
        TutorialPage(
            title: "Welcome to\nChordCrack!",
            description: "Train your ear to identify guitar chords by sound alone. Perfect for developing your musical ear.",
            icon: "guitars.fill",
            color: ColorTheme.primaryGreen
        ),
        TutorialPage(
            title: "How It Works",
            description: "Listen to chord audio and guess which chord is being played. You'll get helpful hints along the way.",
            icon: "ear",
            color: Color.blue
        ),
        TutorialPage(
            title: "Progressive Hints",
            description: "Can't identify the chord? Each attempt provides more help - from slower playback to finger position reveals.",
            icon: "hand.point.up.fill",
            color: Color.orange
        ),
        TutorialPage(
            title: "Practice & Improve",
            description: "Start with the Daily Challenge using basic chords, then progress to Power, Barre, Blues, and Mixed practice modes.",
            icon: "chart.line.uptrend.xyaxis",
            color: Color.purple
        )
    ]
    
    var body: some View {
        ZStack {
            ColorTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                TabView(selection: $currentPage) {
                    ForEach(0..<tutorialPages.count, id: \.self) { index in
                        TutorialPageView(page: tutorialPages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(maxHeight: 500)
                
                Spacer()
                
                bottomSection
            }
            .padding(.horizontal, 24)
        }
    }
    
    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<tutorialPages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? ColorTheme.primaryGreen : ColorTheme.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Navigation buttons
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button("Previous") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(SecondaryTutorialButtonStyle())
                }
                
                Spacer()
                
                if currentPage < tutorialPages.count - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(PrimaryTutorialButtonStyle())
                } else {
                    Button("Start Playing!") {
                        showTutorial = false
                    }
                    .buttonStyle(PrimaryTutorialButtonStyle())
                }
            }
        }
        .padding(.bottom, 40)
    }
}

struct TutorialPage {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct TutorialPageView: View {
    let page: TutorialPage
    
    var body: some View {
        VStack(spacing: 32) {
            Circle()
                .fill(page.color)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: page.icon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true) // This fixes text clipping
                
                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(ColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true) // This fixes text clipping
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

// MARK: - Tutorial Button Styles

struct PrimaryTutorialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(ColorTheme.primaryGreen)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryTutorialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(ColorTheme.textSecondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
