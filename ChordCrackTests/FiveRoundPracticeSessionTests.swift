import Foundation
import Testing
@testable import ChordCrack

@Suite(.serialized)
@MainActor
struct FiveRoundPracticeSessionTests {
    @Test func fiveRoundsScoreOnceAndRestartWithoutCarryingProgress() async throws {
        let session = FiveRoundPracticeSession()
        #expect(!session.answer(.major)) // No answering before listening.
        for index in 0..<5 {
            session.listen()
            #expect(!session.answer(.major)) // Not during loading/playback either.
            try await waitUntil { session.canGuess }
            let choice: FiveRoundPracticeSession.Quality = index == 0 ? .minor : session.round.quality
            #expect(session.answer(choice))
            #expect(!session.answer(choice)) // Double taps cannot add score or results.
            session.next()
        }
        #expect(session.phase == .recap)
        #expect(session.results.count == 5)
        #expect(session.correctCount == 4)
        #expect(session.score == 80)
        #expect(session.missedPairs == ["A"])
        session.next()
        #expect(session.results.count == 5)
        session.restart()
        #expect(session.score == 0 && session.roundIndex == 0 && session.results.isEmpty)
        session.listen() // Same chord can be heard in a new session.
        try await waitUntil { session.canGuess }
        #expect(session.answer(.major))
        #expect(session.score == 20)
        session.stop()
    }

    @Test func failedAndInterruptedAudioCannotUnlockGuessing() async throws {
        var fail = true
        let audio = AudioManager { file in
            if fail { throw URLError(.notConnectedToInternet) }
            try? await Task.sleep(for: .milliseconds(40)) // Emulate a late loader that ignores cancellation.
            return try #require(DesignDemo.stringTone(named: file))
        }
        let session = FiveRoundPracticeSession(audio: audio)
        session.listen()
        try await waitUntil { audio.errorMessage != nil }
        #expect(!session.canGuess && session.results.isEmpty)
        fail = false
        session.listen()
        await Task.yield()
        session.pause()
        try await Task.sleep(for: .milliseconds(400))
        #expect(!audio.isPlaying && !session.canGuess)
        session.resume()
        #expect(session.phase == .listen)
        session.listen()
        try await waitUntil { session.canGuess }
        session.soundEnabled = false
        #expect(!session.canGuess && !audio.isPlaying)
        session.listen()
        #expect(!audio.isLoading)
        session.soundEnabled = true
        session.listen()
        try await waitUntil { session.canGuess }
        #expect(session.answer(.major))
        session.stop()
    }

    @Test func comparisonUsesGuessedShapeAndNextCancelsItsAudio() async throws {
        var loaded: [String] = []
        let audio = AudioManager { file in
            loaded.append(file)
            return try #require(DesignDemo.stringTone(named: file))
        }
        let session = FiveRoundPracticeSession(audio: audio)
        session.listen()
        try await waitUntil { session.canGuess }
        #expect(session.answer(.minor))
        loaded = []
        session.replay(.minor)
        try await waitUntil { audio.isPlaying }
        #expect(loaded == ChordType.aMinor.getStringFiles())
        session.next()
        #expect(!audio.isPlaying && !audio.isLoading)
        #expect(session.roundIndex == 1 && session.phase == .listen)
        try await Task.sleep(for: .milliseconds(150))
        #expect(session.activeReplay == nil && !session.canGuess)
        session.listen()
        try await waitUntil { session.canGuess }
        #expect(session.answer(.major))
        loaded = []
        session.replay(.minor)
        try await waitUntil { audio.isPlaying }
        #expect(loaded == ChordType.aMinor.getStringFiles()) // Actual chord in round two.
        session.pause()
        session.resume()
        #expect(session.phase == .reveal && session.results.count == 2)
        session.stop()
    }

    @Test func exercisePairsContainCorrectMajorAndMinorPitchClasses() {
        let opens = ["E2": 4, "A3": 9, "D3": 2, "G3": 7, "B4": 11, "E4": 4]
        let roots = ["A": 9, "E": 4, "D": 2]
        for round in FiveRoundPracticeSession.rounds {
            for quality in FiveRoundPracticeSession.Quality.allCases {
                let root = roots[round.root]!
                let expected = Set([root, (root + (quality == .major ? 4 : 3)) % 12, (root + 7) % 12])
                let actual = Set(round.chord(for: quality).fingerPositions.map { (opens[$0.string]! + $0.fret) % 12 })
                #expect(actual == expected)
            }
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Timed out waiting for prototype audio/phase")
    }
}
