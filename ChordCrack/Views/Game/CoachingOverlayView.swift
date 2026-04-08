import SwiftUI

/// A floating coaching tooltip that appears during gameplay to guide new users.
/// Automatically dismisses on tap, and each tip only shows once.
struct CoachingOverlayView: View {
    @ObservedObject var coaching = CoachingManager.shared

    var body: some View {
        if let tip = coaching.activeTip {
            VStack {
                if tip.pointsTo == .chordGrid || tip.pointsTo == .hintDots {
                    Spacer()
                }

                tipBubble(tip: tip)

                if tip.pointsTo == .playButton || tip.pointsTo == .top || tip.pointsTo == .guitarNeck {
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: coaching.activeTip)
            .onTapGesture {
                withAnimation {
                    coaching.dismissCurrentTip()
                }
            }
        }
    }

    private func tipBubble(tip: CoachingTip) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(ColorTheme.primaryGreen)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tap to dismiss")
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textTertiary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ColorTheme.primaryGreen.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        )
    }
}
