import SwiftUI

// Primary actions carry the sound family’s color into the practice session.
struct PrimaryGameButtonStyle: ButtonStyle {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(ColorTheme.background)
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
    }
}

struct SecondaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(ColorTheme.primaryGreen)
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(ColorTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
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
            return ColorTheme.primaryGreen
        } else if isWrong {
            return ColorTheme.error
        } else if isSelected {
            return gameType.color
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
            VStack(spacing: 4) {
                Text(chord.displayName).font(.subheadline.weight(.semibold))
                if isCorrect { Image(systemName: "checkmark.circle.fill").font(.caption) }
                if isWrong { Image(systemName: "xmark.circle.fill").font(.caption) }
            }
                .foregroundStyle(isCorrect || isWrong || isSelected ? ColorTheme.background : ColorTheme.textPrimary)
                .padding(.vertical, 10)
                .frame(minHeight: 48)
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
        .buttonStyle(StudioPressStyle())
        .accessibilityLabel(chord.displayName + (isCorrect ? ", correct answer" : isWrong ? ", incorrect answer" : ""))
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
