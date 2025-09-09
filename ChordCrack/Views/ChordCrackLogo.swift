import SwiftUI

/// ChordCrack logo component using the actual logo image
struct ChordCrackLogo: View {
    let size: LogoSize
    let style: LogoStyle
    
    enum LogoSize {
        case small      // 40x40 - for navigation bars
        case medium     // 80x80 - for cards
        case large      // 140x140 - for onboarding
        case hero       // 200x200 - for splash/welcome
        
        var dimension: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 80
            case .large: return 140
            case .hero: return 200
            }
        }
        
        var textSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 28
            case .hero: return 36
            }
        }
    }
    
    enum LogoStyle {
        case iconOnly       // Just the logo
        case withText       // Logo + "ChordCrack" text
        case withTagline    // Logo + text + tagline
    }
    
    var body: some View {
        switch style {
        case .iconOnly:
            logoImage
        case .withText:
            VStack(spacing: size == .small ? 6 : 12) {
                logoImage
                logoText
            }
        case .withTagline:
            VStack(spacing: size == .small ? 6 : 16) {
                logoImage
                logoText
                if size != .small {
                    taglineText
                }
            }
        }
    }
    
    private var logoImage: some View {
        // Use the actual logo image from your assets
        // Make sure to add "ChordCrackLogo" to your Assets.xcassets
        Image("ChordCrackLogo") // Add your logo image to Assets.xcassets with this name
            .resizable()
            .scaledToFit()
            .frame(width: size.dimension, height: size.dimension)
            // If the image doesn't exist, fallback to the designed version
            .overlay(
                Group {
                    if !imageExists {
                        designedLogo
                    }
                }
            )
    }
    
    // Check if image exists (fallback to designed version if not)
    private var imageExists: Bool {
        UIImage(named: "ChordCrackLogo") != nil
    }
    
    // Fallback designed logo matching your actual logo
    private var designedLogo: some View {
        ZStack {
            // Background gradient circle
            Circle()
                .fill(ColorTheme.logoGradient)
                .frame(width: size.dimension, height: size.dimension)
            
            // Guitar pick shape with fretboard
            ZStack {
                // Pick outline
                Path { path in
                    let width = size.dimension * 0.7
                    let height = size.dimension * 0.8
                    let centerX = size.dimension / 2
                    let centerY = size.dimension / 2
                    
                    path.move(to: CGPoint(x: centerX, y: centerY - height/2))
                    path.addQuadCurve(
                        to: CGPoint(x: centerX - width/2, y: centerY + height/3),
                        control: CGPoint(x: centerX - width/2, y: centerY - height/4)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: centerX, y: centerY + height/2),
                        control: CGPoint(x: centerX - width/4, y: centerY + height/2)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: centerX + width/2, y: centerY + height/3),
                        control: CGPoint(x: centerX + width/4, y: centerY + height/2)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: centerX, y: centerY - height/2),
                        control: CGPoint(x: centerX + width/2, y: centerY - height/4)
                    )
                }
                .stroke(ColorTheme.brightGreen, lineWidth: size.dimension * 0.05)
                
                // Fretboard lines
                VStack(spacing: size.dimension * 0.08) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(ColorTheme.lightGreen)
                            .frame(width: size.dimension * 0.35, height: 2)
                    }
                }
                
                // Vertical strings
                HStack(spacing: size.dimension * 0.06) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(ColorTheme.lightGreen.opacity(0.8))
                            .frame(width: 1.5, height: size.dimension * 0.5)
                    }
                }
            }
        }
    }
    
    private var logoText: some View {
        Text("ChordCrack")
            .font(.system(size: size.textSize, weight: .bold, design: .rounded))
            .foregroundColor(ColorTheme.textPrimary)
    }
    
    private var taglineText: some View {
        Text("Master guitar chords by ear")
            .font(.system(size: size.textSize * 0.45, weight: .medium))
            .foregroundColor(ColorTheme.textSecondary)
            .multilineTextAlignment(.center)
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
                .padding(.top, 40)
                
                // Different sizes and styles
                VStack(spacing: 30) {
                    HStack(spacing: 40) {
                        VStack(spacing: 12) {
                            ChordCrackLogo(size: .large, style: .iconOnly)
                            Text("Icon Only")
                                .font(.caption)
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                        
                        VStack(spacing: 12) {
                            ChordCrackLogo(size: .large, style: .withText)
                            Text("With Text")
                                .font(.caption)
                                .foregroundColor(ColorTheme.textSecondary)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        ChordCrackLogo(size: .medium, style: .withText)
                        Text("Medium Size")
                            .font(.caption)
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                    
                    VStack(spacing: 12) {
                        ChordCrackLogo(size: .small, style: .withText)
                        Text("Small Size")
                            .font(.caption)
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(ColorTheme.backgroundGradient.ignoresSafeArea())
    }
}

#Preview {
    LogoShowcaseView()
}
