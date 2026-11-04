import Foundation
import Combine

/// One local result per UTC day. No account, XP, leaderboard or network dependency.
@MainActor
final class DailyRiffStore {
    struct Progress: Codable {
        var answers: [Int] = [] // -1 means skipped.
        var pendingReveal = false
    }
    static let preview = DailyRiffStore(defaults: nil)
    private let defaults: UserDefaults?
    private var memory: [String: Data] = [:]

    init(defaults: UserDefaults?) { self.defaults = defaults }
    func load(_ puzzle: DailyRiffPuzzle) -> Progress {
        let key = "dailyRiff.\(puzzle.id)"
        guard let data = defaults?.data(forKey: key) ?? memory[key],
              let progress = try? JSONDecoder().decode(Progress.self, from: data),
              progress.answers.count <= puzzle.rounds.count,
              !progress.pendingReveal || !progress.answers.isEmpty,
              progress.answers.enumerated().allSatisfy({ index, answer in
                  answer == -1 || puzzle.rounds[index].choices.indices.contains(answer)
              }) else { return Progress() }
        return progress
    }
    func save(_ progress: Progress, for puzzle: DailyRiffPuzzle) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        let key = "dailyRiff.\(puzzle.id)"
        if let defaults { defaults.set(data, forKey: key) }
        else { memory[key] = data }
    }
}

@MainActor
final class DailyRiffSession: ObservableObject {
    enum Phase { case listen, guess, reveal, recap }
    let puzzle: DailyRiffPuzzle
    let audio: AudioManager
    private let store: DailyRiffStore
    @Published private(set) var phase: Phase
    @Published private(set) var answers: [Int]
    @Published private(set) var isPaused = false
    @Published private(set) var activeReference: Int?
    private var playbackGeneration = 0

    init(date: Date = Date(), store: DailyRiffStore? = nil, audio: AudioManager? = nil) {
        puzzle = DailyRiffPuzzle(date: date)
        let storage = store ?? (DesignDemo.isEnabled ? .preview : DailyRiffStore(defaults: .standard))
        self.store = storage
        let progress = storage.load(puzzle)
        answers = progress.answers
        phase = progress.pendingReveal ? .reveal : progress.answers.count == puzzle.rounds.count ? .recap : .listen
        // Reuse the verified, offline open-chord synthesizer used by five-round practice.
        self.audio = audio ?? AudioManager { name in
            guard let data = DesignDemo.stringTone(named: name) else { throw URLError(.cannotDecodeContentData) }
            return data
        }
    }

    var roundIndex: Int { min(phase == .reveal ? answers.count - 1 : answers.count, puzzle.rounds.count - 1) }
    var round: DailyRiffPuzzle.Round { puzzle.rounds[roundIndex] }
    var isBusy: Bool { audio.isLoading || audio.isPlaying }
    var canAnswer: Bool { phase == .guess && !isPaused && !isBusy }
    var canListen: Bool { !isPaused && !isBusy && phase != .recap }
    var correctCount: Int { answers.enumerated().filter { $0.element == puzzle.rounds[$0.offset].correctIndex }.count }
    var lastWasCorrect: Bool { answers.last == round.correctIndex }
    var tiles: String { answers.enumerated().map { $0.element == puzzle.rounds[$0.offset].correctIndex ? "🟩" : "🟨" }.joined() }
    var shareText: String? {
        guard phase == .recap else { return nil }
        return "ChordCrack · Daily Riff\n\(puzzle.dateLabel) · v\(DailyRiffPuzzle.version)\n\(tiles) \(correctCount)/\(puzzle.rounds.count)\nSame day. Same three puzzles.\nPlay Daily Riff in ChordCrack."
    }

    func listen() {
        guard canListen else { return }
        let revealing = phase == .reveal
        if !revealing { phase = .listen }
        activeReference = nil
        let generation = playbackGeneration
        audio.playChordSequence(round.chords, delayBetween: 1.4) { [weak self] in
            guard let self, generation == self.playbackGeneration, !self.isPaused else { return }
            if !revealing { self.phase = .guess }
        }
    }

    func reference(_ index: Int) {
        guard canListen, phase == .listen || phase == .guess,
              round.references.indices.contains(index) else { return }
        activeReference = index
        let generation = playbackGeneration
        audio.playChordSequence([round.references[index]]) { [weak self] in
            guard let self, generation == self.playbackGeneration else { return }
            self.activeReference = nil // Reference playback never unlocks the mystery answer.
        }
    }

    @discardableResult func answer(_ index: Int) -> Bool {
        guard canAnswer, round.choices.indices.contains(index) else { return false }
        record(index)
        return true
    }
    func skip() {
        guard !isPaused, !isBusy, phase == .listen || phase == .guess else { return }
        record(-1)
    }
    private func record(_ index: Int) {
        cancelAudio()
        answers.append(index)
        phase = .reveal
        persist()
    }
    func next() {
        guard phase == .reveal, !isPaused else { return }
        cancelAudio()
        phase = answers.count == puzzle.rounds.count ? .recap : .listen
        persist()
    }
    func pause() {
        guard phase != .recap else { return }
        isPaused = true
        stop()
    }
    func resume() { isPaused = false }
    func stop() {
        cancelAudio()
        if phase == .guess { phase = .listen }
    }
    private func cancelAudio() {
        playbackGeneration += 1
        audio.resetForNewAttempt()
        activeReference = nil
    }
    private func persist() {
        store.save(.init(answers: answers, pendingReveal: phase == .reveal), for: puzzle)
    }
}
