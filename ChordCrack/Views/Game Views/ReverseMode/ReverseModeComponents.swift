import SwiftUI

// MARK: - ChordCrack Logo Extension for Reverse Mode
extension ChordCrackLogo {
    init(size: LogoSize = .medium, style: LogoStyle = .iconOnly, isReversed: Bool = false) {
        self.init(size: size, style: style)
        // You'll need to update the actual ChordCrackLogo implementation
        // to support the isReversed parameter for color changes
    }
}

struct HomeAchievementBadge: View {
    let title: String
    let icon: String
    let isUnlocked: Bool
    let color: Color
    
    // Constructor for Achievement enum
    init(achievement: Achievement, isUnlocked: Bool) {
        self.title = achievement.title
        self.icon = achievement.icon
        self.isUnlocked = isUnlocked
        self.color = achievement.color
    }
    
    // Constructor for ReverseModeAchievement enum
    init(achievement: ReverseModeAchievement, isUnlocked: Bool) {
        self.title = achievement.title
        self.icon = achievement.icon
        self.isUnlocked = isUnlocked
        self.color = achievement.color
    }
    
    // Generic constructor
    init(title: String, icon: String, isUnlocked: Bool, color: Color) {
        self.title = title
        self.icon = icon
        self.isUnlocked = isUnlocked
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color.opacity(0.2) : ColorTheme.secondaryBackground)
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUnlocked ? color : ColorTheme.textTertiary.opacity(0.5))
            }
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textTertiary.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 70)
        }
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}


// MARK: - Home Quick Stat Item (if not already in SharedUIComponents)
struct HomeQuickStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textSecondary)
        }
    }
}

