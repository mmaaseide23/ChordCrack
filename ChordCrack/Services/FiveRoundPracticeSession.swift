import Foundation
import Combine

/// Local, disposable exercise. It has no account, progression, cache or analytics dependency.
@MainActor
final class FiveRoundPracticeSession: ObservableObject {
    enum Quality: String, CaseIterable { case major = "Major", minor = "Minor" }
    enum Phase { case listen, guess, reveal, recap }
    struct Round {
        let root: String
        let major: ChordType
        let minor: ChordType
        let quality: Quality
        var chord: ChordType { chord(for: quality) }
        func chord(for quality: Quality) -> ChordType { quality == .major ? major : minor }
        func name(for quality: Quality) -> String { "\(root) \(quality.rawValue.lowercased())" }
    }
    struct Result: Identifiable {
        let id: Int
        let round: Round
        let guess: Quality
        var isCorrect: Bool { guess == round.quality }
    }

    // Deliberately limited to verified open major/minor shapes, including the same root twice.
    static let rounds: [Round] = [
        Round(root: "A", major: .aMajor, minor: .aMinor, quality: .major),
        Round(root: "A", major: .aMajor, minor: .aMinor, quality: .minor),
        Round(root: "E", major: .eMajor, minor: .eMinor, quality: .major),
        Round(root: "E", major: .eMajor, minor: .eMinor, quality: .minor),
        Round(root: "D", major: .dMajor, minor: .dMinor, quality: .minor)
    ]
    let audio: AudioManager
    @Published private(set) var phase: Phase = .listen
    @Published private(set) var roundIndex = 0
    @Published private(set) var results: [Result] = []
    @Published private(set) var isPaused = false
    @Published private(set) var activeReplay: Quality?
    @Published var soundEnabled = true {
        didSet { if !soundEnabled { interruptAudio() } }
    }

    init(audio: AudioManager? = nil) {
        // Always synthesized, even if this view is accidentally constructed outside demo mode.
        self.audio = audio ?? AudioManager { file in
            guard let data = DesignDemo.stringTone(named: file) else { throw URLError(.cannotDecodeContentData) }
            return data
        }
    }

    var round: Round { Self.rounds[roundIndex] }
    var lastResult: Result? { results.last }
    var correctCount: Int { results.filter(\.isCorrect).count }
    var score: Int { correctCount * 20 }
    var isBusy: Bool { audio.isLoading || audio.isPlaying }
    var canGuess: Bool { phase == .guess && !isPaused && !isBusy && soundEnabled }
    var missedPairs: [String] {
        var seen = Set<String>()
        return results.filter { !$0.isCorrect }.compactMap { seen.insert($0.round.root).inserted ? $0.round.root : nil }
    }

    func listen() {
        guard !isPaused, soundEnabled, !isBusy, phase == .listen || phase == .guess else { return }
        phase = .listen
        let index = roundIndex
        audio.playChordSequence([round.chord]) { [weak self] in
            guard let self, !self.isPaused, self.roundIndex == index, self.phase == .listen else { return }
            self.phase = .guess
        }
    }

    @discardableResult func answer(_ quality: Quality) -> Bool {
        guard canGuess else { return false }
        audio.resetForNewAttempt()
        results.append(Result(id: roundIndex, round: round, guess: quality))
        phase = .reveal
        return true
    }

    func replay(_ quality: Quality) {
        guard phase == .reveal, !isPaused, soundEnabled, !isBusy else { return }
        activeReplay = quality
        audio.playChordSequence([round.chord(for: quality)]) { [weak self] in self?.activeReplay = nil }
    }

    func next() {
        guard phase == .reveal, !isPaused else { return }
        audio.resetForNewRound() // Cancels comparison audio immediately, including a late load.
        activeReplay = nil
        if roundIndex == Self.rounds.count - 1 { phase = .recap }
        else { roundIndex += 1; phase = .listen }
    }

    func pause() {
        guard phase != .recap else { return }
        isPaused = true
        interruptAudio()
    }
    func resume() { isPaused = false }
    func stop() { interruptAudio() }
    func restart() {
        audio.resetForNewRound()
        results = []
        roundIndex = 0
        activeReplay = nil
        isPaused = false
        phase = .listen
    }
    private func interruptAudio() {
        audio.resetForNewAttempt()
        activeReplay = nil
        // An interrupted listen never unlocks an answer; a revealed result stays available.
        if phase == .listen || phase == .guess { phase = .listen }
    }
}
