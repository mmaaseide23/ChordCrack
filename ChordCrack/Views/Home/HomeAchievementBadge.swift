import SwiftUI

struct HomeAchievementBadge: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievement.color.opacity(0.2) : ColorTheme.textTertiary.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: achievement.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isUnlocked ? achievement.color : ColorTheme.textTertiary.opacity(0.5))

                if isUnlocked {
                    Circle()
                        .stroke(achievement.color, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }

            Text(achievement.title)
                .font(.caption2.weight(.medium))
                .foregroundColor(isUnlocked ? ColorTheme.textPrimary : ColorTheme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 180 : 90)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), \(isUnlocked ? "unlocked" : "locked")")
    }
}
