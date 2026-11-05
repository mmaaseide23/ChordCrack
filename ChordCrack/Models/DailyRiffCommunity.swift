import Foundation

/// Display contract for the proposed aggregate RPC. This is not an enabled service.
/// The normal app never submits a Daily Riff result or requests community data.
enum DailyRiffCommunity {
    case unavailable
    case waiting
    case summary(Summary)

    struct Summary: Codable {
        let day: Int
        let version: Int
        let participantsLower: Int
        /// Counts rounded down to five; nil suppresses a group smaller than five.
        let scoreBands: [Int?]
        /// Percentages rounded down to ten, for the five rounds in generator order.
        let roundRates: [Int]

        func isValid(for puzzle: DailyRiffPuzzle) -> Bool {
            day == puzzle.day && version == puzzle.contentVersion && version == 2
                && participantsLower >= 20 && participantsLower <= 100_000_000 && participantsLower % 10 == 0
                && scoreBands.count == 3 && scoreBands.allSatisfy { value in
                    value == nil || (value! >= 0 && value! <= participantsLower + 9 && value! % 5 == 0)
                }
                && scoreBands.compactMap { $0 }.reduce(0, +) <= participantsLower + 9
                && roundRates.count == 5 && roundRates.allSatisfy { (0...100).contains($0) && $0 % 10 == 0 }
        }
        var participantsLabel: String { "\(participantsLower)–\(participantsLower + 9) players" }
        func bandLabel(_ index: Int) -> String {
            guard scoreBands.indices.contains(index), let lower = scoreBands[index] else { return "Small group hidden" }
            return lower == 0 ? "0 players" : "\(lower)–\(lower + 4) players"
        }
        func rateLabel(_ index: Int) -> String {
            let lower = roundRates[index]
            return lower == 100 ? "100%" : "\(lower)–\(lower + 9)%"
        }
    }

    #if DEBUG
    static func syntheticPreview(for puzzle: DailyRiffPuzzle) -> Self {
        .summary(.init(day: puzzle.day, version: 2, participantsLower: 120,
                       scoreBands: [20, 65, 35], roundRates: [80, 60, 50, 80, 60]))
    }
    #endif
}
