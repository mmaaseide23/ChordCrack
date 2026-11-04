import Foundation

/// Versioned, deterministic content. Never use Swift's randomized Hasher or device time zones here.
struct DailyRiffPuzzle {
    static let version = 1
    let day: Int
    let rounds: [Round]

    enum Kind: String { case quality, match, change }
    struct Round {
        let kind: Kind
        let title: String
        let instruction: String
        let chords: [ChordType]
        let choices: [String]
        let correctIndex: Int
        let explanation: String
        let references: [ChordType]
    }

    static let pairs: [(major: ChordType, minor: ChordType)] = [
        (.aMajor, .aMinor), (.dMajor, .dMinor), (.eMajor, .eMinor)
    ]

    init(date: Date = Date()) {
        day = Int(floor(date.timeIntervalSince1970 / 86_400))
        var random = Generator(state: UInt64(bitPattern: Int64(day)) ^ 0x4343524946460001)
        let pair = Self.pairs[random.index(3)]
        let minor = random.index(2) == 1
        let quality = minor ? pair.minor : pair.major
        let references = Self.pairs.map { random.index(2) == 0 ? $0.major : $0.minor }
        let matchIndex = random.index(references.count)
        var first = Self.pairs.map(\.major)
        // Fixed algorithm and order ensure the same puzzle on every device running v1.
        for index in stride(from: first.count - 1, through: 1, by: -1) {
            first.swapAt(index, random.index(index + 1))
        }
        let changedIndex = random.index(first.count)
        var second = first
        second[changedIndex] = Self.pairs.first { $0.major == first[changedIndex] }!.minor
        rounds = [
            Round(kind: .quality, title: "Major or minor?",
                  instruction: "One chord. Two colors. Listen, then trust your ear.",
                  chords: [quality], choices: ["Major", "Minor"], correctIndex: minor ? 1 : 0,
                  explanation: "That was \(quality.rawValue). Listen for the third: it sits one semitone lower in a minor chord.", references: []),
            Round(kind: .match, title: "Find its match",
                  instruction: "Hear the mystery chord. Compare the named references, then choose its match. No perfect pitch needed.",
                  chords: [references[matchIndex]], choices: references.map(\.rawValue), correctIndex: matchIndex,
                  explanation: "The mystery chord matched \(references[matchIndex].rawValue). The reference and mystery use the same voicing.", references: references),
            Round(kind: .change, title: "Spot the switch",
                  instruction: "You’ll hear 1 · 2 · 3, then 1 · 2 · 3 again. Which position changes the second time?",
                  chords: first + second, choices: ["First chord", "Second chord", "Third chord"], correctIndex: changedIndex,
                  explanation: "Position \(changedIndex + 1) changed from \(first[changedIndex].rawValue) to \(second[changedIndex].rawValue). The other two stayed the same.", references: [])
        ]
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: Double(day) * 86_400))
    }
    var id: String { "v\(Self.version).\(day)" }
    var nextDate: Date { Date(timeIntervalSince1970: Double(day + 1) * 86_400) }

    private struct Generator {
        var state: UInt64
        mutating func index(_ count: Int) -> Int {
            state &+= 0x9E3779B97F4A7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            return Int((value ^ (value >> 31)) % UInt64(count))
        }
    }
}
