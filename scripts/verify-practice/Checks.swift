@main struct PracticeChecks {
    @MainActor static func main() async throws {
        var results: [[String: String]] = []
        func run(_ name: String, _ body: () async throws -> Void) async {
            AVAudioPlayer.reset()
            do { try await body(); results.append(["test": name, "status": "passed"]) }
            catch { results.append(["test": name, "status": "failed", "detail": String(describing: error)]) }
        }
        await run("failed load leaves listen available; retry and repeated chord succeed") {
            var fail = true
            let audio = AudioManager { name in
                if fail { throw URLError(.notConnectedToInternet) }
                return DesignDemo.stringTone(named: name)!
            }
            audio.playChord(.aMajor)
            try await eventually { !audio.isLoading }
            try check(audio.errorMessage != nil && !audio.hasPlayedForCurrentChord(.aMajor), "failed load consumed listen")
            fail = false
            audio.playChord(.aMajor)
            try await eventually { audio.isPlaying }
            try check(audio.hasPlayedForCurrentChord(.aMajor), "successful playback did not consume listen")
            audio.resetForNewRound()
            try check(!audio.hasPlayedForCurrentChord(.aMajor), "round retained old listen")
            audio.playChord(.aMajor)
            try await eventually { audio.isPlaying }
            audio.resetForNewRound()
        }
        await run("reset discards a late loader result") {
            let audio = AudioManager { name in
                try? await Task.sleep(for: .milliseconds(100))
                return DesignDemo.stringTone(named: name)!
            }
            audio.playChord(.aMajor)
            await Task.yield()
            audio.resetForNewRound()
            try await Task.sleep(for: .milliseconds(150))
            try check(!audio.isPlaying && !audio.isLoading && AVAudioPlayer.started == 0, "late playback escaped cancellation")
        }
        await run("corrupt or partial chord never starts") {
            var count = 0
            let audio = AudioManager { name in
                count += 1
                return count == 2 ? Data("corrupt".utf8) : DesignDemo.stringTone(named: name)!
            }
            audio.playChord(.aMajor)
            try await eventually { !audio.isLoading }
            try check(audio.errorMessage != nil && AVAudioPlayer.started == 0 && !audio.hasPlayedForCurrentChord(.aMajor), "partial chord started or consumed listen")
        }
        await run("player startup failure remains retryable") {
            let audio = AudioManager { DesignDemo.stringTone(named: $0)! }
            AVAudioPlayer.startSucceeds = false
            audio.playChord(.aMajor)
            try await eventually { !audio.isLoading }
            try check(audio.errorMessage != nil && !audio.hasPlayedForCurrentChord(.aMajor), "player failure consumed listen")
            AVAudioPlayer.startSucceeds = true
            audio.playChord(.aMajor)
            try await eventually { audio.isPlaying }
            audio.resetForNewRound()
        }
        await run("five rounds score once, recap and restart") {
            let session = FiveRoundPracticeSession()
            try check(!session.answer(.major), "answered before listen")
            for index in 0..<5 {
                session.listen()
                try check(!session.answer(.major), "answered during loading")
                try await eventually { session.canGuess }
                let guess: FiveRoundPracticeSession.Quality = index == 0 ? .minor : session.round.quality
                try check(session.answer(guess), "answer refused")
                try check(!session.answer(guess), "double answer accepted")
                session.next()
            }
            try check(session.phase == .recap && session.score == 80 && session.results.count == 5 && session.missedPairs == ["A"], "incorrect recap")
            session.next()
            try check(session.results.count == 5, "recap mutated on next")
            session.restart()
            try check(session.score == 0 && session.roundIndex == 0 && session.results.isEmpty, "restart retained results")
            session.stop()
        }
        await run("pause and sound preference require a fresh listen") {
            let session = FiveRoundPracticeSession()
            session.listen()
            session.pause()
            try await Task.sleep(for: .milliseconds(160))
            try check(!session.canGuess && !session.audio.isPlaying, "paused audio unlocked guessing")
            session.resume()
            session.listen()
            try await eventually { session.canGuess }
            session.soundEnabled = false
            try check(!session.canGuess && !session.audio.isPlaying, "sound disable left guessing unlocked")
            session.listen()
            try check(!session.audio.isLoading, "disabled sound started loading")
            session.soundEnabled = true
            session.listen()
            try await eventually { session.canGuess }
            session.stop()
        }
        await run("comparison plays guessed and actual chords; next cancels") {
            var loaded: [String] = []
            let audio = AudioManager { name in loaded.append(name); return DesignDemo.stringTone(named: name)! }
            let session = FiveRoundPracticeSession(audio: audio)
            session.listen()
            try await eventually { session.canGuess }
            try check(session.answer(.minor), "mistake refused")
            loaded = []
            session.replay(.minor)
            try await eventually { audio.isPlaying }
            try check(loaded == ChordType.aMinor.getStringFiles(), "guessed comparison wrong")
            session.next()
            try check(!audio.isPlaying && session.activeReplay == nil && session.roundIndex == 1, "comparison not cancelled")
            session.listen()
            try await eventually { session.canGuess }
            try check(session.answer(.major), "second answer refused")
            loaded = []
            session.replay(.minor)
            try await eventually { audio.isPlaying }
            try check(loaded == ChordType.aMinor.getStringFiles(), "actual comparison wrong")
            session.pause(); session.resume()
            try check(session.phase == .reveal && session.results.count == 2, "pause lost revealed result")
            session.stop()
        }
        await run("exercise shapes have the declared pitches") {
            let opens = ["E2":4, "A3":9, "D3":2, "G3":7, "B4":11, "E4":4]
            let roots = ["A":9, "E":4, "D":2]
            for round in FiveRoundPracticeSession.rounds {
                for quality in FiveRoundPracticeSession.Quality.allCases {
                    let root = roots[round.root]!
                    let expected = Set([root, (root + (quality == .major ? 4 : 3)) % 12, (root + 7) % 12])
                    let actual = Set(round.chord(for: quality).fingerPositions.map { (opens[$0.string]! + $0.fret) % 12 })
                    try check(actual == expected, "mislabeled chord pitch classes")
                }
            }
        }
        await run("difficulty always retains correct chord with bounded choices") {
            for level in DifficultyLevel.allCases {
                for chord in ChordType.allCases {
                    let options = level.filteredChords(from: ChordType.allCases, correctChord: chord)
                    try check(options.contains(chord), "correct answer removed")
                    try check(level.optionCount == 0 || options.count == level.optionCount, "wrong option count")
                }
            }
        }
        let failed = results.filter { $0["status"] == "failed" }.count
        let output: [String: Any] = ["passed": results.count - failed, "failed": failed, "tests": results, "audio_backend": "silent in-memory substitute", "network": false]
        print(String(data: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
        if failed > 0 { throw CheckFailure.failed("Regression failure") }
    }
}
