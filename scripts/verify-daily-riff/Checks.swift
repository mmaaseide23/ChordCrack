@main struct RiffChecks {
    @MainActor static func main() async throws {
        var results: [[String: String]] = []
        let date = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")!
        func session(_ store: DailyRiffStore? = nil, _ audio: AudioManager? = nil) -> DailyRiffSession {
            DailyRiffSession(date: date, store: store ?? DailyRiffStore(defaults: nil), audio: audio)
        }
        func run(_ name: String, _ body: () async throws -> Void) async {
            AVAudioPlayer.reset()
            do { try await body(); results.append(["test": name, "status": "passed"]) }
            catch { results.append(["test": name, "status": "failed", "detail": String(describing: error)]) }
        }
        func fingerprint(_ puzzle: DailyRiffPuzzle) -> String {
            puzzle.rounds.map { "\($0.kind.rawValue):\($0.chords.map(\.rawValue).joined(separator: ",")):\($0.correctIndex)" }.joined(separator: "|")
        }
        await run("UTC boundary and stable shared set across a year") {
            let midnight = ISO8601DateFormatter().date(from: "2026-11-04T00:00:00Z")!
            let a = DailyRiffPuzzle(date: midnight)
            let b = DailyRiffPuzzle(date: midnight.addingTimeInterval(86_399))
            try check(a.id == b.id && fingerprint(a) == fingerprint(b), "same UTC day differs")
            try check(DailyRiffPuzzle(date: midnight.addingTimeInterval(-1)).id != a.id, "previous day retained")
            try check(DailyRiffPuzzle(date: midnight.addingTimeInterval(86_400)).id != a.id, "next day retained")
            try check(a.dateLabel == "2026-11-04" && a.nextDate == midnight.addingTimeInterval(86_400), "wrong date label/reset")
            var variants = Set<String>()
            for offset in 0..<365 {
                let puzzle = DailyRiffPuzzle(date: midnight.addingTimeInterval(Double(offset) * 86_400))
                try check(puzzle.rounds.map(\.kind) == [.quality, .match, .change], "wrong daily mix")
                variants.insert(fingerprint(puzzle))
                let change = puzzle.rounds[2]
                let changed = (0..<3).filter { change.chords[$0] != change.chords[$0 + 3] }
                try check(changed == [change.correctIndex], "ambiguous change puzzle")
                let match = puzzle.rounds[1]
                try check(Set(match.choices).count == 3 && match.chords == [match.references[match.correctIndex]], "ambiguous match puzzle")
            }
            try check(variants.count > 150, "daily generator repeats too often")
        }
        await run("every eligible chord has a complete major/minor triad and valid synthesized audio") {
            let opens = ["E2":4, "A3":9, "D3":2, "G3":7, "B4":11, "E4":4]
            for (pair, root) in zip(DailyRiffPuzzle.pairs, [9, 2, 4]) {
                for (chord, third) in [(pair.major, 4), (pair.minor, 3)] {
                    let pitches = Set(chord.fingerPositions.map { (opens[$0.string]! + $0.fret) % 12 })
                    try check(pitches == Set([root, (root + third) % 12, (root + 7) % 12]), "incorrect pitches")
                    for file in chord.getStringFiles() {
                        let data = DesignDemo.stringTone(named: file)
                        try check(data?.prefix(4) == Data("RIFF".utf8) && (data?.count ?? 0) > 44, "missing synthesized string")
                    }
                }
            }
        }
        await run("listen gate, invalid and duplicate answers") {
            let s = session()
            try check(!s.answer(0) && s.shareText == nil, "answer/share before listen")
            s.listen()
            try check(!s.answer(0), "answered while loading")
            try await eventually { s.canAnswer }
            try check(!s.answer(99), "invalid answer accepted")
            try check(s.answer(s.round.correctIndex) && !s.answer(0), "duplicate answer accepted")
            try check(s.correctCount == 1 && s.phase == .reveal && s.answers.count == 1, "wrong reveal")
            s.stop()
        }
        await run("three puzzle journey saves first answers and shares no solutions") {
            let storage = DailyRiffStore(defaults: nil)
            let s = session(storage)
            for index in 0..<3 {
                s.listen(); try await eventually { s.canAnswer }
                let answer = index == 1 ? (s.round.correctIndex + 1) % 3 : s.round.correctIndex
                try check(s.answer(answer), "answer rejected")
                s.next()
            }
            try check(s.phase == .recap && s.correctCount == 2 && s.tiles == "🟩🟨🟩", "wrong score")
            let expected = "ChordCrack · Daily Riff\n2026-11-04 · v1\n🟩🟨🟩 2/3\nSame day. Same three puzzles.\nPlay Daily Riff in ChordCrack."
            try check(s.shareText == expected, "spoiler or unstable share format")
            s.listen(); s.skip(); s.next()
            try check(!s.answer(0) && !s.isBusy && s.answers.count == 3, "finished result mutated")
            let reopened = session(storage)
            try check(reopened.phase == .recap && reopened.shareText == expected, "result lost on reopen")
        }
        await run("pending feedback survives closing and resuming") {
            let storage = DailyRiffStore(defaults: nil)
            let s = session(storage)
            s.skip()
            let reopened = session(storage)
            try check(reopened.phase == .reveal && reopened.roundIndex == 0 && reopened.answers == [-1], "feedback lost")
            reopened.next()
            let next = session(storage)
            try check(next.phase == .listen && next.roundIndex == 1 && !next.canAnswer, "progress lost")
            next.skip(); next.next(); next.skip()
            let last = session(storage)
            try check(last.phase == .reveal && last.roundIndex == 2, "last feedback lost")
            last.next()
            try check(session(storage).phase == .recap, "recap not saved")
        }
        await run("new UTC day starts fresh without mutating previous result") {
            let storage = DailyRiffStore(defaults: nil)
            let old = session(storage)
            for _ in 0..<3 { old.skip(); old.next() }
            let next = DailyRiffSession(date: date.addingTimeInterval(86_400), store: storage)
            try check(next.answers.isEmpty && next.phase == .listen, "new day has old score")
            try check(old.puzzle.dateLabel == "2026-11-04" && session(storage).answers.count == 3, "old session changed day")
        }
        await run("references never unlock answers and preserve a completed mystery listen") {
            var loaded: [String] = []
            let audio = AudioManager { name in loaded.append(name); return DesignDemo.stringTone(named: name)! }
            let s = session(nil, audio)
            s.skip(); s.next()
            s.reference(1); try await eventually { !s.isBusy }
            try check(!s.canAnswer && loaded == s.round.references[1].getStringFiles(), "reference unlocked mystery")
            s.listen(); try await eventually { s.canAnswer }
            s.reference(0)
            try check(!s.canAnswer, "answered over reference playback")
            try await eventually { !s.isBusy }
            try check(s.canAnswer && s.activeReference == nil, "reference lost completed mystery")
            s.stop()
        }
        await run("failed/partial loads and startup failure are retryable without scoring") {
            var failure = true
            let audio = AudioManager { name in
                if failure { throw URLError(.notConnectedToInternet) }
                return DesignDemo.stringTone(named: name)!
            }
            let s = session(nil, audio)
            s.listen(); try await eventually { !s.isBusy }
            try check(audio.errorMessage != nil && !s.canAnswer && s.answers.isEmpty, "failed load unlocked answer")
            failure = false; AVAudioPlayer.startSucceeds = false
            s.listen(); try await eventually { !s.isBusy }
            try check(audio.errorMessage != nil && !s.canAnswer, "failed start unlocked answer")
            AVAudioPlayer.startSucceeds = true
            s.listen(); try await eventually { s.canAnswer }
            s.stop()
        }
        await run("pause and close cancel late playback and require a new listen") {
            let audio = AudioManager { name in
                try? await Task.sleep(for: .milliseconds(100))
                return DesignDemo.stringTone(named: name)!
            }
            let s = session(nil, audio)
            s.listen(); await Task.yield(); s.pause()
            try await Task.sleep(for: .milliseconds(180))
            try check(AVAudioPlayer.started == 0 && !s.canAnswer && !s.isBusy, "late playback escaped pause")
            s.resume(); s.listen(); try await eventually { s.canAnswer }
            s.stop()
            try check(!s.canAnswer && s.phase == .listen, "close retained guess gate")
        }
        await run("next cancels reveal replay without losing saved result") {
            let s = session()
            s.skip(); s.listen()
            try await eventually { s.audio.isPlaying }
            s.next()
            try check(!s.isBusy && s.roundIndex == 1 && s.answers == [-1], "next leaked audio")
        }
        await run("persistent storage roundtrip and malformed data validation") {
            let suite = "DailyRiffTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let s = session(DailyRiffStore(defaults: defaults))
            s.skip()
            try check(session(DailyRiffStore(defaults: defaults)).answers == [-1], "disk progress not saved")
            for json in ["garbage", "{\"answers\":[99],\"pendingReveal\":true}", "{\"answers\":[],\"pendingReveal\":true}", "{\"answers\":[0,0,0,0],\"pendingReveal\":false}"] {
                defaults.set(Data(json.utf8), forKey: "dailyRiff.\(s.puzzle.id)")
                try check(session(DailyRiffStore(defaults: defaults)).answers.isEmpty, "corrupt progress accepted")
            }
        }
        let failed = results.filter { $0["status"] == "failed" }.count
        let output: [String: Any] = ["passed": results.count - failed, "failed": failed, "tests": results,
                                    "audio_backend": "silent in-memory substitute", "network": false]
        print(String(data: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
        if failed > 0 { throw CheckFailure.failed("Daily Riff regression failure") }
    }
}
