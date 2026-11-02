import SwiftUI

struct ChordSelectionView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedChords: [ChordType] = ChordType.basicChords

    var body: some View {
        VStack(spacing: 10) {
            // Compact header with inline attempts
            HStack {
                Text("What did you hear?")
                    .font(.headline)
                    .foregroundColor(ColorTheme.textPrimary)

                Spacer()

                // Inline attempt dots
                HStack(spacing: 6) {
                    ForEach(0..<gameManager.maxAttempts, id: \.self) { index in
                        Circle()
                            .fill(attemptColor(for: index))
                            .frame(width: 10, height: 10)
                    }
                }
            }

            // Chord grid
            chordGrid
        }
        .padding(.vertical, 12)
        .onAppear { updateDisplayedChords() }
        .onChange(of: gameManager.currentChord) { _, _ in updateDisplayedChords() }
    }

    private var chordGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3), spacing: 8) {
            ForEach(displayedChords, id: \.id) { chord in
                chordButton(for: chord)
            }
        }
    }

    private func updateDisplayedChords() {
        guard let correctChord = gameManager.currentChord else {
            displayedChords = ChordType.basicChords
            return
        }
        displayedChords = DifficultyLevel.current.filteredChords(
            from: ChordType.basicChords,
            correctChord: correctChord
        )
    }
    
    private func chordButton(for chord: ChordType) -> some View {
        Button(action: { selectChord(chord) }) {
            VStack(spacing: 5) {
                Text(chord.displayName).font(.subheadline.weight(.semibold))
                if isCorrect(chord) { Image(systemName: "checkmark.circle.fill").font(.caption) }
                if isWrong(chord) { Image(systemName: "xmark.circle.fill").font(.caption) }
            }
                .foregroundStyle(isCorrect(chord) || isWrong(chord) || isSelected(chord) ? ColorTheme.background : ColorTheme.textPrimary)
                .padding(.vertical, 12)
                .frame(minHeight: 52)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonColor(for: chord))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor(for: chord), lineWidth: isCorrect(chord) ? 2 : 0)
                        )
                )
        }
        .disabled(gameManager.gameState != .playing)
        .buttonStyle(StudioPressStyle())
        .accessibilityLabel(chord.displayName + (isCorrect(chord) ? ", correct answer" : isWrong(chord) ? ", incorrect answer" : ""))
        .accessibilityIdentifier("answer.\(chord.rawValue)")
    }
    
    private func buttonColor(for chord: ChordType) -> Color {
        if isCorrect(chord) {
            return ColorTheme.primaryGreen
        } else if isWrong(chord) {
            return ColorTheme.error
        } else if isSelected(chord) {
            return ColorTheme.primaryGreen.opacity(0.7)
        } else {
            return ColorTheme.secondaryBackground
        }
    }
    
    private func borderColor(for chord: ChordType) -> Color {
        if isCorrect(chord) {
            return ColorTheme.primaryGreen.opacity(0.8)
        } else {
            return Color.clear
        }
    }
    
    private func isSelected(_ chord: ChordType) -> Bool {
        return chord == gameManager.selectedChord
    }
    
    private func isCorrect(_ chord: ChordType) -> Bool {
        return gameManager.gameState == .answered && chord == gameManager.currentChord
    }
    
    private func isWrong(_ chord: ChordType) -> Bool {
        return gameManager.gameState == .answered && chord == gameManager.selectedChord && chord != gameManager.currentChord
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
        HapticManager.shared.buttonTap()
        gameManager.submitGuess(chord)
    }
}

#Preview {
    ChordSelectionView()
        .environmentObject(GameManager())
        .background(ColorTheme.background)
}
