import SwiftUI

/// Professional color theme system for ChordCrack
/// Optimized for dark mode with excellent accessibility and visual hierarchy
struct ColorTheme {
    
    // MARK: - Background Colors
    
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04) // #0a0a0a
    static let secondaryBackground = Color(red: 0.1, green: 0.1, blue: 0.1) // #1a1a1a
    static let cardBackground = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    static let surfaceSecondary = Color(red: 0.12, green: 0.12, blue: 0.12) // #1f1f1f
    
    // MARK: - Brand Colors
    
    static let primaryGreen = Color(red: 0, green: 0.78, blue: 0.32) // #00C851
    static let accentGreen = Color(red: 0, green: 0.6, blue: 0.25) // #009940
    static let lightGreen = Color(red: 0.2, green: 0.9, blue: 0.4) // #33E566
    
    // MARK: - Text Colors
    
    static let textPrimary = Color(red: 0.94, green: 0.94, blue: 0.94) // #f0f0f0
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.7) // #b3b3b3
    static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.5) // #808080
    
    // MARK: - Status Colors
    
    static let error = Color(red: 0.9, green: 0.2, blue: 0.2) // #e63333
    static let success = Color(red: 0.2, green: 0.8, blue: 0.3) // #33cc4d
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.0) // #ffcc00
    
    // MARK: - Accessibility Colors
    
    /// High contrast version of primary green for important UI elements
    static let accessibilityPrimary = Color(red: 0.1, green: 0.9, blue: 0.4) // #1ae666
    
    /// High contrast text for critical information
    static let accessibilityText = Color.white
    
    // MARK: - Gradient Definitions
    
    static let primaryGradient = LinearGradient(
        colors: [primaryGreen, lightGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [cardBackground, secondaryBackground],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [background, secondaryBackground.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - View Extensions

extension View {
    
    /// Applies the standard app background
    func themedBackground() -> some View {
        self.background(ColorTheme.background.ignoresSafeArea())
    }
    
    /// Applies the standard card styling without shadows
    func themedCard() -> some View {
        self
            .background(ColorTheme.cardBackground)
            .cornerRadius(12)
    }
    
    /// Applies primary button styling
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.primaryGreen)
            )
    }
    
    /// Applies secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(ColorTheme.primaryGreen)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.primaryGreen, lineWidth: 2)
            )
    }
    
    /// Applies standard text field styling
    func themedTextField() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ColorTheme.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            )
    }
    
    /// Applies error state styling
    func errorState() -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.error, lineWidth: 2)
            )
    }
    
    /// Applies success state styling
    func successState() -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.success, lineWidth: 2)
            )
    }
}

// MARK: - Color Accessibility Helpers

extension ColorTheme {
    
    /// Returns appropriate text color for given background
    static func textColor(for backgroundColor: Color) -> Color {
        // For dark backgrounds, use light text
        if backgroundColor == background || backgroundColor == secondaryBackground || backgroundColor == cardBackground {
            return textPrimary
        }
        // For light/colored backgrounds, use dark text
        return Color.black
    }
    
    /// Returns high contrast version of color if accessibility features are enabled
    static func accessibleColor(_ color: Color) -> Color {
        // In a production app, this would check system accessibility settings
        // For now, return the original color
        return color
    }
    
    /// Validates color contrast ratio (simplified implementation)
    static func hasGoodContrast(foreground: Color, background: Color) -> Bool {
        // This is a simplified check - in production, you'd calculate actual contrast ratios
        return true // Placeholder for actual contrast calculation
    }
}

// MARK: - Dynamic Color Support

extension ColorTheme {
    
    /// Adapts colors for different UI states
    enum UIState {
        case normal
        case pressed
        case disabled
        case focused
    }
    
    static func adaptiveColor(_ baseColor: Color, for state: UIState) -> Color {
        switch state {
        case .normal:
            return baseColor
        case .pressed:
            return baseColor.opacity(0.8)
        case .disabled:
            return baseColor.opacity(0.4)
        case .focused:
            return baseColor.opacity(0.9)
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension ColorTheme {
    
    /// Returns all theme colors for preview purposes
    static var allColors: [(String, Color)] {
        return [
            ("Background", background),
            ("Secondary Background", secondaryBackground),
            ("Card Background", cardBackground),
            ("Primary Green", primaryGreen),
            ("Accent Green", accentGreen),
            ("Light Green", lightGreen),
            ("Text Primary", textPrimary),
            ("Text Secondary", textSecondary),
            ("Text Tertiary", textTertiary),
            ("Error", error),
            ("Success", success),
            ("Warning", warning)
        ]
    }
}

struct ColorThemePreview: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(ColorTheme.allColors, id: \.0) { colorInfo in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorInfo.1)
                            .frame(height: 60)
                        
                        Text(colorInfo.0)
                            .font(.caption)
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                }
            }
            .padding()
        }
        .background(ColorTheme.background)
        .navigationTitle("Color Theme")
    }
}

#Preview {
    ColorThemePreview()
}
#endif
