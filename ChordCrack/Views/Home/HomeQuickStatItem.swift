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
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundColor(ColorTheme.textPrimary)

            Text(label)
                .font(.caption2)
                .foregroundColor(ColorTheme.textSecondary)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}
