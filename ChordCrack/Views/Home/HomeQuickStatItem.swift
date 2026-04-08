import SwiftUI

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
