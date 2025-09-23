import SwiftUI

/// Professional color theme system for ChordCrack
/// Updated with Reverse Mode purple/violet theme
struct ColorTheme {
    
    // MARK: - Background Colors (Exactly matching logo background)
    
    // Normal mode colors (green theme)
    static let background = Color(red: 0.059, green: 0.129, blue: 0.184)
    static let secondaryBackground = Color(red: 0.12, green: 0.20, blue: 0.24)
    static let cardBackground = Color(red: 0.14, green: 0.22, blue: 0.26)
    static let surfaceSecondary = Color(red: 0.11, green: 0.18, blue: 0.22)
    
    // MARK: - Reverse Mode Colors (NEW - Purple/Violet Theme)
    
    static let reverseBackground = Color(red: 0.08, green: 0.06, blue: 0.15) // Deep purple-black
    static let reverseSecondaryBackground = Color(red: 0.15, green: 0.12, blue: 0.22) // Lighter purple
    static let reverseCardBackground = Color(red: 0.18, green: 0.14, blue: 0.26) // Purple card
    static let reverseSurfaceSecondary = Color(red: 0.13, green: 0.10, blue: 0.20) // Mid purple
    
    // MARK: - Brand Colors (Normal Mode - Green)
    
    static let primaryGreen = Color(red: 0.2, green: 0.78, blue: 0.55)
    static let accentGreen = Color(red: 0.15, green: 0.70, blue: 0.48)
    static let lightGreen = Color(red: 0.4, green: 0.86, blue: 0.6)
    static let brightGreen = Color(red: 0.5, green: 0.9, blue: 0.65)
    
    // MARK: - Reverse Mode Primary Colors (NEW - Purple/Violet)
    
    static let primaryPurple = Color(red: 0.58, green: 0.35, blue: 0.92) // Bright purple
    static let accentPurple = Color(red: 0.50, green: 0.28, blue: 0.85) // Deeper purple
    static let lightPurple = Color(red: 0.68, green: 0.45, blue: 0.95) // Light purple
    static let brightPurple = Color(red: 0.75, green: 0.55, blue: 0.98) // Bright violet
    
    // MARK: - Text Colors
    
    static let textPrimary = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let textSecondary = Color(red: 0.65, green: 0.75, blue: 0.78)
    static let textTertiary = Color(red: 0.45, green: 0.55, blue: 0.58)
    
    // MARK: - Status Colors
    
    static let error = Color(red: 0.95, green: 0.35, blue: 0.35)
    static let success = primaryGreen
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.2)
    
    // MARK: - Reverse Mode Status Colors (NEW)
    
    static let reverseSuccess = primaryPurple
    static let reverseAccent = Color(red: 0.9, green: 0.6, blue: 0.9) // Pink-purple accent
    
    // MARK: - Accessibility Colors
    
    static let accessibilityPrimary = brightGreen
    static let accessibilityText = Color.white
    
    // MARK: - Gradient Definitions
    
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
    
    // MARK: - Reverse Mode Gradients (NEW)
    
    static let reversePrimaryGradient = LinearGradient(
        colors: [accentPurple, primaryPurple, lightPurple, brightPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let reverseLogoGradient = LinearGradient(
        colors: [primaryPurple, lightPurple],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let reverseCardGradient = LinearGradient(
        colors: [reverseCardBackground, reverseSecondaryBackground],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Dynamic Theme Functions (NEW)
    
    /// Returns the appropriate background color based on reverse mode state
    static func dynamicBackground(isReversed: Bool) -> Color {
        isReversed ? reverseBackground : background
    }
    
    /// Returns the appropriate secondary background based on reverse mode
    static func dynamicSecondaryBackground(isReversed: Bool) -> Color {
        isReversed ? reverseSecondaryBackground : secondaryBackground
    }
    
    /// Returns the appropriate card background based on reverse mode
    static func dynamicCardBackground(isReversed: Bool) -> Color {
        isReversed ? reverseCardBackground : cardBackground
    }
    
    /// Returns the appropriate primary color based on reverse mode
    static func dynamicPrimary(isReversed: Bool) -> Color {
        isReversed ? primaryPurple : primaryGreen
    }
    
    /// Returns the appropriate accent color based on reverse mode
    static func dynamicAccent(isReversed: Bool) -> Color {
        isReversed ? accentPurple : accentGreen
    }
    
    /// Returns the appropriate gradient based on reverse mode
    static func dynamicGradient(isReversed: Bool) -> LinearGradient {
        isReversed ? reversePrimaryGradient : primaryGradient
    }
    
    /// Returns the appropriate logo gradient based on reverse mode
    static func dynamicLogoGradient(isReversed: Bool) -> LinearGradient {
        isReversed ? reverseLogoGradient : logoGradient
    }
    
    // Simple solid backgrounds
    static let backgroundSolid = background
    static let reverseBackgroundSolid = reverseBackground
    
    // Subtle gradient options
    static let backgroundGradient = LinearGradient(
        colors: [background, secondaryBackground],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let reverseBackgroundGradient = LinearGradient(
        colors: [reverseBackground, reverseSecondaryBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Extensions (Updated for Reverse Mode)

extension View {
    
    /// Applies the standard app background (dynamic based on reverse mode)
    func themedBackground(isReversed: Bool = false) -> some View {
        self.background(ColorTheme.dynamicBackground(isReversed: isReversed).ignoresSafeArea())
    }
    
    /// Applies the standard card styling (dynamic based on reverse mode)
    func themedCard(isReversed: Bool = false) -> some View {
        self
            .background(ColorTheme.dynamicCardBackground(isReversed: isReversed))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(ColorTheme.dynamicPrimary(isReversed: isReversed).opacity(0.2), lineWidth: 1)
            )
    }
    
    /// Applies seamless card styling that blends with background
    func seamlessCard(isReversed: Bool = false) -> some View {
        self
            .background(ColorTheme.dynamicCardBackground(isReversed: isReversed).opacity(0.6))
            .cornerRadius(16)
    }
    
    /// Applies primary button styling with gradient (dynamic)
    func primaryButtonStyle(isReversed: Bool = false) -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.dynamicLogoGradient(isReversed: isReversed))
            )
    }
    
    /// Applies secondary button styling (dynamic)
    func secondaryButtonStyle(isReversed: Bool = false) -> some View {
        self
            .foregroundColor(ColorTheme.dynamicPrimary(isReversed: isReversed))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTheme.dynamicPrimary(isReversed: isReversed), lineWidth: 2)
            )
    }
    
    /// Applies standard text field styling (dynamic)
    func themedTextField(isReversed: Bool = false) -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.dynamicSecondaryBackground(isReversed: isReversed))
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
    
    /// Applies success state styling (dynamic)
    func successState(isReversed: Bool = false) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isReversed ? ColorTheme.reverseSuccess : ColorTheme.success, lineWidth: 2)
            )
    }
}

// MARK: - Color Accessibility Helpers (Updated)

extension ColorTheme {
    
    /// Returns appropriate text color for given background
    static func textColor(for backgroundColor: Color) -> Color {
        // For dark backgrounds, use light text
        if backgroundColor == background || backgroundColor == secondaryBackground ||
           backgroundColor == cardBackground || backgroundColor == reverseBackground ||
           backgroundColor == reverseSecondaryBackground || backgroundColor == reverseCardBackground {
            return textPrimary
        }
        // For light/colored backgrounds, use dark text
        return background
    }
    
    /// Returns high contrast version of color if accessibility features are enabled
    static func accessibleColor(_ color: Color) -> Color {
        // In a production app, this would check system accessibility settings
        return color
    }
    
    /// Validates color contrast ratio
    static func hasGoodContrast(foreground: Color, background: Color) -> Bool {
        // Simplified check - in production, calculate actual contrast ratios
        return true
    }
}

// MARK: - Dynamic Color Support (Updated)

extension ColorTheme {
    
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

// MARK: - Reverse Mode Theme Manager (NEW)

class ThemeManager: ObservableObject {
    @Published var isReverseModeEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isReverseModeEnabled, forKey: "isReverseModeEnabled")
        }
    }
    
    init() {
        self.isReverseModeEnabled = UserDefaults.standard.bool(forKey: "isReverseModeEnabled")
    }
    
    func toggleReverseMode() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isReverseModeEnabled.toggle()
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension ColorTheme {
    
    /// Returns all theme colors for preview purposes (updated with reverse mode colors)
    static var allColors: [(String, Color)] {
        return [
            ("Background", background),
            ("Secondary Background", secondaryBackground),
            ("Card Background", cardBackground),
            ("Primary Green", primaryGreen),
            ("Accent Green", accentGreen),
            ("Light Green", lightGreen),
            ("Bright Green", brightGreen),
            ("Reverse Background", reverseBackground),
            ("Reverse Secondary", reverseSecondaryBackground),
            ("Reverse Card", reverseCardBackground),
            ("Primary Purple", primaryPurple),
            ("Accent Purple", accentPurple),
            ("Light Purple", lightPurple),
            ("Bright Purple", brightPurple),
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
    @State private var isReversed = false
    
    var body: some View {
        ScrollView {
            Toggle("Reverse Mode", isOn: $isReversed)
                .padding()
            
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
        .background(ColorTheme.dynamicBackground(isReversed: isReversed))
        .navigationTitle("Color Theme")
    }
}

#Preview {
    ColorThemePreview()
}
#endif
