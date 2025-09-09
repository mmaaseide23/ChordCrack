import SwiftUI

// MARK: - Shared Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(ColorTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ColorTheme.secondaryBackground)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
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
