import SwiftUI

/// Professional ChordCrack logo component with dynamic sizing
struct ChordCrackLogo: View {
    let size: LogoSize
    let style: LogoStyle
    
    enum LogoSize {
        case small      // 32x32 - for navigation bars
        case medium     // 60x60 - for cards
        case large      // 120x120 - for onboarding
        case hero       // 160x160 - for splash/welcome
        
        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 60
            case .large: return 120
            case .hero: return 160
            }
        }
        
        var iconSize: CGFloat {
            return dimension * 0.4
        }
        
        var textSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 24
            case .hero: return 32
            }
        }
    }
    
    enum LogoStyle {
        case iconOnly       // Just the circular logo
        case withText       // Logo + "ChordCrack" text
        case withTagline    // Logo + text + tagline
        case minimal        // Simple text treatment
    }
    
    var body: some View {
        switch style {
        case .iconOnly:
            logoIcon
        case .withText:
            VStack(spacing: size == .small ? 4 : 8) {
                logoIcon
                logoText
            }
        case .withTagline:
            VStack(spacing: size == .small ? 4 : 12) {
                logoIcon
                logoText
                if size != .small {
                    taglineText
                }
            }
        case .minimal:
            minimalistText
        }
    }
    
    private var logoIcon: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(ColorTheme.primaryGreen, lineWidth: size.dimension * 0.08)
                .frame(width: size.dimension, height: size.dimension)
            
            // Inner circle with gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ColorTheme.lightGreen, ColorTheme.primaryGreen],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size.dimension * 0.5
                    )
                )
                .frame(width: size.dimension * 0.8, height: size.dimension * 0.8)
            
            // Guitar/music symbol
            ZStack {
                // Guitar neck representation
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: size.iconSize * 0.3, height: size.iconSize * 0.9)
                
                // Fret markers
                VStack(spacing: size.iconSize * 0.1) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(ColorTheme.primaryGreen)
                            .frame(width: size.iconSize * 0.5, height: 1)
                    }
                }
                
                // Sound waves
                HStack(spacing: size.iconSize * 0.1) {
                    ForEach(0..<2) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 2, height: size.iconSize * 0.3 + CGFloat(index * 4))
                            .offset(x: size.iconSize * 0.4)
                    }
                }
            }
        }
    }
    
    private var logoText: some View {
        Text("ChordCrack")
            .font(.system(size: size.textSize, weight: .bold, design: .rounded))
            .foregroundColor(ColorTheme.primaryGreen)
    }
    
    private var taglineText: some View {
        Text("Master guitar chords through sound")
            .font(.system(size: size.textSize * 0.5, weight: .medium))
            .foregroundColor(ColorTheme.textSecondary)
            .multilineTextAlignment(.center)
    }
    
    private var minimalistText: some View {
        HStack(spacing: 8) {
            // Small icon
            Circle()
                .fill(ColorTheme.primaryGreen)
                .frame(width: size.textSize * 1.2, height: size.textSize * 1.2)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: size.textSize * 0.6, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text("ChordCrack")
                .font(.system(size: size.textSize, weight: .bold, design: .rounded))
                .foregroundColor(ColorTheme.textPrimary)
        }
    }
}

// MARK: - Logo Usage Examples

struct LogoShowcaseView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                VStack(spacing: 20) {
                    Text("Logo Variations")
                        .font(.title)
                        .foregroundColor(ColorTheme.textPrimary)
                    
                    // Hero logo
                    ChordCrackLogo(size: .hero, style: .withTagline)
                }
                
                // Different sizes and styles
                VStack(spacing: 20) {
                    HStack(spacing: 30) {
                        VStack(spacing: 8) {
                            ChordCrackLogo(size: .large, style: .iconOnly)
                            Text("Icon Only")
                                .font(.caption)
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                        
                        VStack(spacing: 8) {
                            ChordCrackLogo(size: .large, style: .withText)
                            Text("With Text")
                                .font(.caption)
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                    }
                    
                    VStack(spacing: 8) {
                        ChordCrackLogo(size: .medium, style: .minimal)
                        Text("Minimal Style")
                            .font(.caption)
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(ColorTheme.background.ignoresSafeArea())
    }
}
