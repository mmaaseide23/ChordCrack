import UIKit

/// Manages haptic feedback throughout the app with semantic methods.
/// Checks user preference before firing — callers don't need to check.
@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        // Pre-prepare generators for low latency
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
    }

    // MARK: - Semantic Feedback Methods

    /// Player guessed correctly
    func correctAnswer() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Player guessed incorrectly
    func incorrectAnswer() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    /// Subtle tap for button presses (chord selection, play button)
    func buttonTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Medium impact for significant UI actions (starting a game, navigating)
    func mediumImpact() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Heavy impact for streak milestones and combo effects
    func streakMilestone() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    /// Selection change feedback (toggling options, picker changes)
    func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    /// Game over / completion celebration
    func celebration() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
        // Double tap for celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.impactHeavy.impactOccurred()
            self?.impactHeavy.prepare()
        }
    }

    /// Warning feedback (last attempt, time running out)
    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }
}
