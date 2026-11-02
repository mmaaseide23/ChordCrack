import SwiftUI

struct HomePracticeModeCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let description: String
    let icon: String
    let color: Color
    let difficulty: String
    let progress: Double
    let destination: AnyView

    private let analytics = FirebaseAnalyticsManager.shared

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(color)
                    }

                    VStack(spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(ColorTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(description)
                            .font(.caption)
                            .foregroundColor(ColorTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Text(difficulty)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.15))
                        )
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)

                Spacer(minLength: 16)

                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.caption2)
                            .foregroundColor(ColorTheme.textTertiary)

                        Spacer()

                        Text("\(Int(min(1, max(progress, 0.0)) * 100))%")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(color)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ColorTheme.secondaryBackground)
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(
                                    width: geometry.size.width * min(1, max(progress, 0.0)),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 164)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 0 : 236)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(StudioPressStyle())
        .accessibilityIdentifier(title == "Chord Library" ? "home.library" : "home.\(title)")
        .simultaneousGesture(TapGesture().onEnded {
            analytics.trackFeatureUsage("practice_mode_selected", properties: ["mode": title])
        })
    }
}
