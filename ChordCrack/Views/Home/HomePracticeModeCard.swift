import SwiftUI

struct HomePracticeModeCard: View {
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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ColorTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(ColorTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Text(difficulty)
                        .font(.system(size: 10, weight: .bold))
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

                Spacer()

                VStack(spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 11))
                            .foregroundColor(ColorTheme.textTertiary)

                        Spacer()

                        Text("\(Int(max(progress, 0.0) * 100))%")
                            .font(.system(size: 11, weight: .semibold))
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
                                    width: geometry.size.width * max(progress, 0.0),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(width: 140, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ColorTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onTapGesture {
            analytics.trackFeatureUsage("practice_mode_selected", properties: ["mode": title])
        }
    }
}
