import SwiftUI

// MARK: - Game Button Styles

struct PrimaryGameButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(ColorTheme.primaryGreen)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.primaryGreen, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Styled Chord Button Component
struct StyledChordButton: View {
    let chord: ChordType
    let gameType: GameType
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let isDisabled: Bool
    var isCompact: Bool = false
    let action: () -> Void
    
    private var buttonColor: Color {
        if isCorrect {
            return gameType.color
        } else if isWrong {
            return ColorTheme.error
        } else if isSelected {
            return gameType.color.opacity(0.7)
        } else {
            return ColorTheme.secondaryBackground
        }
    }
    
    private var borderColor: Color {
        if isCorrect {
            return gameType.color.opacity(0.8)
        } else {
            return Color.clear
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(chord.displayName)
                .font(.system(size: isCompact ? 11 : 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: isCompact ? 32 : 44)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                        .fill(buttonColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 8 : 12)
                                .stroke(borderColor, lineWidth: isCorrect ? 2 : 0)
                        )
                )
        }
        .disabled(isDisabled)
        .scaleEffect(isSelected && !isDisabled ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

// MARK: - Card Components

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ColorTheme.primaryGreen)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(ColorTheme.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
        )
    }
}
