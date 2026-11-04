import Foundation
import Combine

/// Separate storage: never reads or writes Daily Riff v1 results.
@MainActor final class SongGuessingStore {
    private let defaults: UserDefaults?
    private var memory: [String: String] = [:]
    init(defaults: UserDefaults?) { self.defaults = defaults }
    func answer(for round: ClearedSongRound) -> String? {
        let value = defaults?.string(forKey: round.id) ?? memory[round.id]
        return round.choices.contains(where: { $0.id == value }) ? value : nil
    }
    func save(answer: String, for round: ClearedSongRound) {
        guard self.answer(for: round) == nil,
              round.choices.contains(where: { $0.id == answer }) else { return }
        if let defaults { defaults.set(answer, forKey: round.id) }
        else { memory[round.id] = answer }
    }
}

@MainActor final class SongGuessingSession: ObservableObject {
    enum Phase { case unavailable, listen, guess, reveal }
    let round: ClearedSongRound?
    let player: SongClipPlayer
    private let store: SongGuessingStore
    @Published private(set) var phase: Phase
    @Published private(set) var answerID: String?
    @Published private(set) var isPaused = false

    // Callers must resolve the player's actual supported territory before enabling.
    // Locale is not evidence of territorial clearance.
    init(date: Date = Date(), territory: String = "", catalog: SongClipCatalog = .current,
         enabled: Bool = SongRiffFeature.isEnabled, use: SongClipCatalog.Use = .production,
         store: SongGuessingStore? = nil, player: SongClipPlayer? = nil) {
        self.player = player ?? SongClipPlayer()
        self.store = store ?? SongGuessingStore(defaults: .standard)
        round = try? catalog.round(date: date, territory: territory, enabled: enabled, use: use)
        if let round {
            let saved = self.store.answer(for: round)
            answerID = saved
            phase = saved == nil ? .listen : .reveal
        } else { phase = .unavailable }
    }
    var canListen: Bool { round != nil && !isPaused && !player.isBusy }
    var canAnswer: Bool { phase == .guess && !isPaused && !player.isBusy }
    var isCorrect: Bool { answerID != nil && answerID == round?.clip.id }
    var shareText: String? {
        guard let round, phase == .reveal else { return nil }
        return "ChordCrack · Song Riff\n\(round.dateLabel) · v1 · catalog \(round.catalogVersion)\n\(isCorrect ? "🟩 1/1" : "🟨 0/1")\nPlay Song Riff in ChordCrack."
    }
    func listen() {
        guard let round, canListen else { return }
        let revealing = phase == .reveal
        if !revealing { phase = .listen }
        player.play(round) { [weak self] result in
            guard let self, !self.isPaused, !revealing else { return }
            if case .success = result { self.phase = .guess }
        }
    }
    @discardableResult func answer(_ id: String) -> Bool {
        guard let round, canAnswer, round.choices.contains(where: { $0.id == id }) else { return false }
        player.cancel()
        store.save(answer: id, for: round)
        answerID = store.answer(for: round)
        phase = .reveal
        return true
    }
    func pause() { isPaused = true; stop() }
    func resume() { isPaused = false } // Never automatically starts playback.
    func stop() {
        player.cancel()
        if phase == .guess { phase = .listen }
    }
}
