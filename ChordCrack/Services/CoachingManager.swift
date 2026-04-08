import Foundation

/// Manages first-time coaching tips that appear during actual gameplay.
/// Instead of a tutorial users skip, coaching happens inline as they play.
/// Each tip shows once, keyed by a unique identifier stored in UserDefaults.
final class CoachingManager: ObservableObject {
    static let shared = CoachingManager()

    private let defaults = UserDefaults.standard
    private let seenTipsKey = "CoachingManager.seenTips"

    /// The currently active coaching tip (only one at a time).
    @Published var activeTip: CoachingTip?

    /// All tips that have been seen/dismissed.
    private var seenTips: Set<String> {
        get { Set(defaults.stringArray(forKey: seenTipsKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: seenTipsKey) }
    }

    private init() {}

    /// Attempt to show a coaching tip. Only shows if the user hasn't seen it.
    func showTipIfNeeded(_ tip: CoachingTip) {
        guard !seenTips.contains(tip.id) else { return }
        guard activeTip == nil else { return } // Don't overlap tips
        activeTip = tip
    }

    /// Dismiss the current tip and mark it as seen.
    func dismissCurrentTip() {
        if let tip = activeTip {
            var tips = seenTips
            tips.insert(tip.id)
            seenTips = tips
        }
        activeTip = nil
    }

    /// Whether a specific tip has been seen.
    func hasSeenTip(_ tipId: String) -> Bool {
        return seenTips.contains(tipId)
    }

    /// Reset all coaching (e.g., when tutorial is reset).
    func resetAllTips() {
        defaults.removeObject(forKey: seenTipsKey)
        activeTip = nil
    }
}

/// Represents a single coaching tooltip.
struct CoachingTip: Identifiable, Equatable {
    let id: String
    let message: String
    let icon: String
    let pointsTo: TipAnchor

    enum TipAnchor {
        case playButton
        case chordGrid
        case hintDots
        case guitarNeck
        case top
    }

    static func == (lhs: CoachingTip, rhs: CoachingTip) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Predefined Tips

    /// First thing: tap play to hear the chord
    static let tapPlay = CoachingTip(
        id: "first_tap_play",
        message: "Tap to hear a mystery chord!",
        icon: "play.circle.fill",
        pointsTo: .playButton
    )

    /// After playing: now select a chord
    static let selectChord = CoachingTip(
        id: "first_select_chord",
        message: "Now pick which chord you think it is!",
        icon: "hand.tap.fill",
        pointsTo: .chordGrid
    )

    /// After wrong guess: hints get better
    static let hintsImprove = CoachingTip(
        id: "first_hints_improve",
        message: "Wrong guess? No worries — each attempt gives you better hints!",
        icon: "lightbulb.fill",
        pointsTo: .hintDots
    )

    /// Audio options appear at attempt 3
    static let audioOptions = CoachingTip(
        id: "first_audio_options",
        message: "New audio options unlocked! Try Bass or Treble for extra clues.",
        icon: "speaker.wave.3.fill",
        pointsTo: .playButton
    )

    /// After first correct answer
    static let firstCorrect = CoachingTip(
        id: "first_correct_answer",
        message: "Great ear! The faster you guess, the more points you earn.",
        icon: "star.fill",
        pointsTo: .top
    )
}
