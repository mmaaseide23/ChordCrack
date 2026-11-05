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
            let a = DailyRiffPuzzle(date: midnight, version: 1)
            let b = DailyRiffPuzzle(date: midnight.addingTimeInterval(86_399), version: 1)
            try check(fingerprint(a) == "quality:E:0|match:Am:0|change:E,D,A,Em,D,A:0", "v1 content changed; preserve or version the generator")
            try check(a.id == b.id && fingerprint(a) == fingerprint(b), "same UTC day differs")
            try check(DailyRiffPuzzle(date: midnight.addingTimeInterval(-1), version: 1).id != a.id, "previous day retained")
            try check(DailyRiffPuzzle(date: midnight.addingTimeInterval(86_400), version: 1).id != a.id, "next day retained")
            try check(a.dateLabel == "2026-11-04" && a.nextDate == midnight.addingTimeInterval(86_400), "wrong date label/reset")
            var variants = Set<String>()
            for offset in 0..<365 {
                let puzzle = DailyRiffPuzzle(date: midnight.addingTimeInterval(Double(offset) * 86_400), version: 1)
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
        await run("five-round v2 content is deterministic, unambiguous and preserves the v1 prefix") {
            try check(fingerprint(DailyRiffPuzzle(date: date)) == "quality:E:0|match:Am:0|change:E,D,A,Em,D,A:0|same:Dm,Dm:0|minor:A,Dm,E:1", "v2 generator changed; preserve or version the content")
            let midnight = ISO8601DateFormatter().date(from: "2026-11-04T00:00:00Z")!
            let start = DailyRiffPuzzle(date: midnight)
            let end = DailyRiffPuzzle(date: midnight.addingTimeInterval(86_399))
            try check(start.id == end.id && fingerprint(start) == fingerprint(end), "v2 changed inside a UTC day")
            try check(DailyRiffPuzzle(date: midnight.addingTimeInterval(-1)).day == start.day - 1, "v2 previous UTC day incorrect")
            try check(DailyRiffPuzzle(date: midnight.addingTimeInterval(86_400)).day == start.day + 1, "v2 next UTC day incorrect")
            for offset in 0..<365 {
                let day = date.addingTimeInterval(Double(offset) * 86_400)
                let p = DailyRiffPuzzle(date: day)
                let legacy = DailyRiffPuzzle(date: day, version: 1)
                try check(p.contentVersion == 2 && p.rounds.map(\.kind) == [.quality,.match,.change,.same,.minor], "wrong v2 mix")
                try check(fingerprint(p) == fingerprint(DailyRiffPuzzle(date: day)), "unstable v2")
                try check(Array(p.rounds.prefix(3)).map(\.chords) == legacy.rounds.map(\.chords), "v1 chords shifted")
                try check(Array(p.rounds.prefix(3)).map(\.correctIndex) == legacy.rounds.map(\.correctIndex), "v1 answers shifted")
                let compare = p.rounds[3]
                try check((compare.chords[0] == compare.chords[1]) == (compare.correctIndex == 0), "ambiguous comparison")
                let find = p.rounds[4]
                let minors = find.chords.indices.filter { index in DailyRiffPuzzle.pairs.contains { $0.minor == find.chords[index] } }
                try check(minors == [find.correctIndex], "ambiguous minor")
            }
        }
        await run("legacy completed and pending results retain their version and first answers") {
            let legacy = DailyRiffPuzzle(date: date, version: 1)
            let storage = DailyRiffStore(defaults: nil)
            let answers = legacy.rounds.map(\.correctIndex)
            storage.save(.init(answers: answers, pendingReveal: false), for: legacy)
            let s = session(storage)
            try check(s.puzzle.contentVersion == 1 && s.phase == .recap && s.correctCount == 3, "legacy result remapped")
            try check(s.shareText?.contains("v1\n🟩🟩🟩 3/3\nSame day. Same three puzzles.") == true, "legacy share changed")
            storage.save(.init(answers: [-1], pendingReveal: true), for: legacy)
            let pending = session(storage)
            try check(pending.phase == .reveal && pending.puzzle.contentVersion == 1 && pending.answers == [-1], "legacy pending answer lost")
            let tomorrow = DailyRiffSession(date: date.addingTimeInterval(86_400), store: storage)
            try check(tomorrow.puzzle.contentVersion == 2 && tomorrow.answers.isEmpty, "new day did not upgrade")
        }
        await run("legacy disk save survives restart and invalid newer data") {
            let suite = "LegacyDailyRiffTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let legacy = DailyRiffPuzzle(date: date, version: 1)
            DailyRiffStore(defaults: defaults).save(.init(answers: [-1], pendingReveal: true), for: legacy)
            defaults.set(Data("invalid".utf8), forKey: "dailyRiff.\(DailyRiffPuzzle(date: date).id)")
            let restored = DailyRiffSession(date: date, store: DailyRiffStore(defaults: defaults))
            try check(restored.puzzle.contentVersion == 1 && restored.phase == .reveal && restored.answers == [-1], "legacy disk result lost")
            restored.next(); restored.skip(); restored.next(); restored.skip(); restored.next()
            let reopened = DailyRiffSession(date: date, store: DailyRiffStore(defaults: defaults))
            try check(reopened.phase == .recap && reopened.answers == [-1,-1,-1] && reopened.shareText?.contains("0/3") == true, "legacy completion lost")
        }
        await run("community display rejects wrong sets, small cohorts and malformed aggregates") {
            let puzzle = DailyRiffPuzzle(date: date)
            func aggregate(day: Int? = nil, version: Int = 2, players: Int = 120,
                           bands: [Int?] = [nil, 65, 35], rates: [Int] = [80,60,50,80,60]) -> DailyRiffCommunity.Summary {
                .init(day: day ?? puzzle.day, version: version, participantsLower: players, scoreBands: bands, roundRates: rates)
            }
            let valid = aggregate()
            try check(valid.isValid(for: puzzle) && valid.bandLabel(0) == "Small group hidden", "valid aggregate or suppression failed")
            try check(valid.participantsLabel == "120–129 players" && valid.rateLabel(0) == "80–89%", "coarse range mislabeled")
            for bad in [aggregate(day: puzzle.day-1), aggregate(version: 1), aggregate(players: 19), aggregate(players: 121),
                        aggregate(bands: [1,65,35]), aggregate(bands: [nil,65]), aggregate(bands: [120,120,120]),
                        aggregate(rates: [101,60,50,80,60]), aggregate(rates: [81,60,50,80,60]), aggregate(rates: [])] {
                try check(!bad.isValid(for: puzzle), "invalid aggregate accepted")
            }
            let json = try JSONEncoder().encode(valid)
            let decoded = try JSONDecoder().decode(DailyRiffCommunity.Summary.self, from: json)
            try check(decoded.isValid(for: puzzle), "aggregate transport roundtrip failed")
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
        await run("five puzzle journey saves first answers and shares no solutions") {
            let storage = DailyRiffStore(defaults: nil)
            let s = session(storage)
            for index in 0..<5 {
                s.listen(); try await eventually { s.canAnswer }
                let answer = index == 1 ? (s.round.correctIndex + 1) % 3 : s.round.correctIndex
                try check(s.answer(answer), "answer rejected")
                s.next()
            }
            try check(s.phase == .recap && s.correctCount == 4 && s.tiles == "🟩🟨🟩🟩🟩", "wrong score")
            let expected = "ChordCrack · Daily Riff\n2026-11-04 · v2\n🟩🟨🟩🟩🟩 4/5\nSame day. Same five puzzles.\nPlay Daily Riff in ChordCrack."
            try check(s.shareText == expected, "spoiler or unstable share format")
            s.listen(); s.skip(); s.next()
            try check(!s.answer(0) && !s.isBusy && s.answers.count == 5, "finished result mutated")
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
            for _ in 0..<3 { next.skip(); next.next() }; next.skip()
            let last = session(storage)
            try check(last.phase == .reveal && last.roundIndex == 4, "last feedback lost")
            last.next()
            try check(session(storage).phase == .recap, "recap not saved")
        }
        await run("new UTC day starts fresh without mutating previous result") {
            let storage = DailyRiffStore(defaults: nil)
            let old = session(storage)
            for _ in 0..<5 { old.skip(); old.next() }
            let next = DailyRiffSession(date: date.addingTimeInterval(86_400), store: storage)
            try check(next.answers.isEmpty && next.phase == .listen, "new day has old score")
            try check(old.puzzle.dateLabel == "2026-11-04" && session(storage).answers.count == 5, "old session changed day")
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
        await run("failed loads and startup failure are retryable without scoring") {
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
            for json in ["garbage", "{\"answers\":[99],\"pendingReveal\":true}", "{\"answers\":[],\"pendingReveal\":true}", "{\"answers\":[0,0,0,0,0,0,0],\"pendingReveal\":false}"] {
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
