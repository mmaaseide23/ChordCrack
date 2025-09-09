import SwiftUI

/// Professional color theme system for ChordCrack
/// Updated to exactly match the logo's background color
struct ColorTheme {
    
    // MARK: - Background Colors (Exactly matching logo background)
    
    // Updated to match your logo's exact dark blue-gray background
    static let background = Color(red: 0.059, green: 0.129, blue: 0.184)
    static let secondaryBackground = Color(red: 0.12, green: 0.20, blue: 0.24) // #1F3239 - Slightly lighter
    static let cardBackground = Color(red: 0.14, green: 0.22, blue: 0.26) // #243842 - Card variant that blends seamlessly
    static let surfaceSecondary = Color(red: 0.11, green: 0.18, blue: 0.22) // #1C2E35
    
    // MARK: - Brand Colors (Matching logo's gradient greens)
    
    static let primaryGreen = Color(red: 0.2, green: 0.78, blue: 0.55) // #33C78C - Main teal-green
    static let accentGreen = Color(red: 0.15, green: 0.70, blue: 0.48) // #26B27A - Darker teal-green
    static let lightGreen = Color(red: 0.4, green: 0.86, blue: 0.6) // #66DB99 - Bright lime green
    static let brightGreen = Color(red: 0.5, green: 0.9, blue: 0.65) // #7FE5A6 - Gradient end color
    
    // MARK: - Text Colors
    
    static let textPrimary = Color(red: 0.94, green: 0.96, blue: 0.97) // #F0F5F7 - Slightly blue-tinted white
    static let textSecondary = Color(red: 0.65, green: 0.75, blue: 0.78) // #A6BFC7
    static let textTertiary = Color(red: 0.45, green: 0.55, blue: 0.58) // #738C94
    
    // MARK: - Status Colors
    
    static let error = Color(red: 0.95, green: 0.35, blue: 0.35) // #F25959
    static let success = primaryGreen // Use brand green for success
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.2) // #FFBF33
    
    // MARK: - Accessibility Colors
    
    /// High contrast version of primary green for important UI elements
    static let accessibilityPrimary = brightGreen
    
    /// High contrast text for critical information
    static let accessibilityText = Color.white
    
    // MARK: - Gradient Definitions (Matching logo gradient)
    
    static let primaryGradient = LinearGradient(
        colors: [accentGreen, primaryGreen, lightGreen, brightGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let logoGradient = LinearGradient(
        colors: [primaryGreen, lightGreen],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let cardGradient = LinearGradient(
        colors: [cardBackground, secondaryBackground],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Simple solid background - exact match to logo
    static let backgroundSolid = background
    
    // Subtle gradient option if needed
    static let backgroundGradient = LinearGradient(
        colors: [background, secondaryBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Extensions

extension View {
    
    /// Applies the standard app background
    func themedBackground() -> some View {
        self.background(ColorTheme.background.ignoresSafeArea())
    }
    
    /// Applies the standard card styling without harsh borders
    func themedCard() -> some View {
        self
            .background(ColorTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ColorTheme.primaryGreen.opacity(0.2), lineWidth: 1)
            )
    }
    
    /// Applies seamless card styling that blends with background
    func seamlessCard() -> some View {
        self
            .background(ColorTheme.cardBackground.opacity(0.6))
            .cornerRadius(16)
    }
    
    /// Applies primary button styling with gradient
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.logoGradient)
            )
    }
    
    /// Applies secondary button styling
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(ColorTheme.primaryGreen)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
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
        return background
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
            ("Bright Green", brightGreen),
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
