import SwiftUI

struct ChordSelectionView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showParticles = false
    
    var body: some View {
        VStack(spacing: 16) {
            if !gameManager.attempts.isEmpty {
                previousAttemptsView
            }
            
            headerSection
            
            // Use styled chord grid with 4 columns for basic chords
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(ChordType.basicChords) { chord in
                    StyledChordButton(
                        chord: chord,
                        gameType: .dailyChallenge,
                        isSelected: chord == gameManager.selectedChord,
                        isCorrect: gameManager.gameState == .answered && chord == gameManager.currentChord,
                        isWrong: gameManager.gameState == .answered && chord == gameManager.selectedChord && chord != gameManager.currentChord,
                        isDisabled: gameManager.gameState != .playing,
                        isCompact: true
                    ) {
                        selectChord(chord)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTheme.primaryGreen.opacity(0.3), lineWidth: 1)
                )
        )
        .onChange(of: gameManager.gameState) { oldValue, newValue in
            if newValue == .answered && gameManager.selectedChord == gameManager.currentChord {
                showParticles = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showParticles = false
                }
            }
        }
    }
    
    private var previousAttemptsView: some View {
        VStack(spacing: 12) {
            Text("Previous Attempts:")
                .font(.system(size: 14))
                .foregroundColor(ColorTheme.textSecondary)
            
            HStack(spacing: 12) {
                ForEach(0..<gameManager.maxAttempts, id: \.self) { index in
                    Circle()
                        .fill(attemptColor(for: index))
                        .frame(width: 16, height: 16)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Select the chord:")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Rectangle()
                .fill(ColorTheme.primaryGreen)
                .frame(width: 60, height: 2)
                .cornerRadius(1)
        }
    }
    
    private func attemptColor(for index: Int) -> Color {
        if index < gameManager.attempts.count {
            if let attempt = gameManager.attempts[index] {
                return attempt == gameManager.currentChord ? ColorTheme.primaryGreen : ColorTheme.error
            }
        } else if index == gameManager.currentAttempt - 1 {
            return ColorTheme.accentGreen
        }
        return ColorTheme.textTertiary.opacity(0.3)
    }
    
    private func selectChord(_ chord: ChordType) {
        guard gameManager.gameState == .playing else { return }
        gameManager.submitGuess(chord)
    }
}

#Preview {
    ChordSelectionView()
        .environmentObject(GameManager())
        .background(ColorTheme.background)
}
