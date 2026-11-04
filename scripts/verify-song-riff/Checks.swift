// Synthetic metadata and a state-only fake: no audio bytes, files, speakers, or downloads.
struct CheckFailure: Error, CustomStringConvertible { let description: String }
func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw CheckFailure(description: message) }
}
func rejects(_ body: () throws -> Void) throws {
    do { try body() } catch { return }
    throw CheckFailure(description: "Expected rejection")
}
@MainActor func eventually(_ predicate: () -> Bool) async throws {
    for _ in 0..<500 {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(2))
    }
    throw CheckFailure(description: "State did not settle")
}
@MainActor final class SilentBackend: SongClipPlaybackBackend {
    var sampleRate = 100.0
    var frameLength: Int64 = 1_000
    var range: SongFrameRange?
    var completed: (() -> Void)?
    var starts = 0
    var stops = 0
    var failStart = false
    func play(_ range: SongFrameRange, completion: @escaping () -> Void) throws {
        starts += 1
        if failStart { throw SongPlaybackError.unavailable }
        self.range = range; completed = completion
    }
    func stop() { stops += 1 }
}

@main struct SongChecks {
    @MainActor static func main() async throws {
        let date = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")!
        let evidence = SongRightsEvidence(basis: .publicDomain,
            source: URL(string: "https://example.invalid/synthetic-test-only")!,
            rationale: "SYNTHETIC TEST ONLY — not a legal clearance or a real song.", attribution: "Test fixture")
        let review = SongRightsReview(composition: evidence, arrangement: evidence, recording: evidence,
            reviewer: "Synthetic test harness", reviewedAt: date.addingTimeInterval(-86_400),
            expiresAt: nil, territories: ["US"], permitsCommercialQuiz: true, permitsBundledExcerpt: true,
            permitsAttributionAfterReveal: true, maximumExcerptSeconds: 5)
        let clips = (0..<3).map { index in
            SongClip(id: "synthetic-\(index)", title: "Synthetic fixture \(index) — not a song",
                performer: "No performer; silent test double", kind: .syntheticTestFixture,
                bundledFile: "nonexistent-test-\(index).wav", sha256: String(repeating: "0", count: 64),
                startSeconds: 1.005, durationSeconds: 0.5, rights: review)
        }
        func catalog(_ edit: (inout SongClip) -> Void = { _ in }) -> SongClipCatalog {
            SongClipCatalog(version: 1, clips: clips.map { clip in var copy = clip; edit(&copy); return copy })
        }
        func round(_ catalog: SongClipCatalog? = nil, at time: Date? = nil) throws -> ClearedSongRound {
            try (catalog ?? SongClipCatalog(version: 1, clips: clips)).round(date: time ?? date,
                territory: "US", enabled: true, use: .syntheticTests)
        }
        func session(_ backend: SilentBackend, store: SongGuessingStore? = nil) -> SongGuessingSession {
            SongGuessingSession(date: date, territory: "US", catalog: catalog(), enabled: true,
                use: .syntheticTests, store: store ?? SongGuessingStore(defaults: nil),
                player: SongClipPlayer(now: { date }, makeBackend: { _ in backend }))
        }
        var results: [[String: String]] = []
        func run(_ name: String, _ body: () async throws -> Void) async {
            do { try await body(); results.append(["test": name, "status": "passed"]) }
            catch { results.append(["test": name, "status": "failed", "detail": String(describing: error)]) }
        }
        await run("release gate, empty catalog, and synthetic isolation") {
            try check(!SongRiffFeature.isEnabled && SongClipCatalog.current.clips.isEmpty, "Release accidentally enabled")
            try rejects { _ = try catalog().round(date: date, territory: "US") }
            try rejects { _ = try SongClipCatalog.current.round(date: date, territory: "US", enabled: true) }
            try rejects { _ = try catalog().round(date: date, territory: "US", enabled: true, use: .production) }
            var factories = 0
            let s = SongGuessingSession(player: SongClipPlayer(makeBackend: { _ in factories += 1; return SilentBackend() }))
            s.listen()
            try check(s.phase == .unavailable && !s.canListen && !s.answer("synthetic-0") && factories == 0, "Disabled mode performed work")
        }
        await run("composition, arrangement, recording and all usage grants are required") {
            let edits: [(inout SongClip) -> Void] = [
                { $0.rights.composition.basis = .unreviewed }, { $0.rights.arrangement.basis = .unreviewed },
                { $0.rights.recording.basis = .unreviewed }, { $0.rights.reviewer = " " },
                { $0.rights.permitsCommercialQuiz = false }, { $0.rights.permitsBundledExcerpt = false },
                { $0.rights.permitsAttributionAfterReveal = false }, { $0.rights.maximumExcerptSeconds = 0.1 },
                { $0.rights.recording.source = URL(string: "http://example.invalid")! },
                { $0.rights.arrangement.rationale = " " },
                { $0.rights.recording.basis = .licensed; $0.rights.recording.attribution = "" }
            ]
            for edit in edits { try rejects { _ = try round(catalog(edit)) } }
        }
        await run("territory and review expiry fail closed") {
            try rejects { _ = try catalog().round(date: date, territory: "GB", enabled: true, use: .syntheticTests) }
            try rejects { _ = try catalog().round(date: date, territory: "us", enabled: true, use: .syntheticTests) }
            try rejects { _ = try round(catalog { $0.rights.expiresAt = date }) }
            try rejects { _ = try round(catalog { $0.rights.reviewedAt = date.addingTimeInterval(1) }) }
        }
        await run("licensed evidence requires attribution, license link and modification notice") {
            let licensed = catalog {
                $0.rights.recording.basis = .licensed
                $0.rights.recording.licenseURL = URL(string: "https://example.invalid/test-license")!
                $0.rights.recording.modificationNotice = "SYNTHETIC TEST ONLY; no audio exists."
            }
            _ = try round(licensed)
            for field in 0..<3 {
                var changed = licensed.clips
                for index in changed.indices {
                    if field == 0 { changed[index].rights.recording.licenseURL = nil }
                    if field == 1 { changed[index].rights.recording.modificationNotice = "" }
                    if field == 2 { changed[index].rights.recording.attribution = "" }
                }
                try rejects { _ = try round(SongClipCatalog(version: 1, clips: changed)) }
            }
        }
        await run("malformed assets and ambiguous choices fail closed") {
            let edits: [(inout SongClip) -> Void] = [
                { $0.id = "" }, { $0.title = "" }, { $0.performer = "" },
                { $0.bundledFile = "../song.wav" }, { $0.bundledFile = "https://example.invalid/a.wav" },
                { $0.bundledFile = "a.mp3" }, { $0.sha256 = "not-a-hash" },
                { $0.startSeconds = -.infinity }, { $0.startSeconds = -1 },
                { $0.durationSeconds = .nan }, { $0.durationSeconds = 31 }, { $0.durationSeconds = 0 }
            ]
            for edit in edits { try rejects { _ = try round(catalog(edit)) } }
            try rejects { _ = try round(SongClipCatalog(version: 1, clips: [clips[0], clips[0], clips[1]])) }
            try rejects { _ = try round(catalog { $0.title = "same title" }) }
        }
        await run("same UTC day and catalog version have stable separate identity") {
            let midnight = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 86_400) * 86_400)
            let a = try round(at: midnight), b = try round(at: midnight.addingTimeInterval(86_399))
            let reversed = try round(SongClipCatalog(version: 1, clips: clips.reversed()))
            try check(a.id == b.id && a.clip.id == b.clip.id && a.choices.map(\.id) == reversed.choices.map(\.id), "Daily order drifted")
            try check(a.id == "songRiff.v1.catalog1.20761" && a.dateLabel == "2026-11-04", "Identity changed")
            try check(try round(at: midnight.addingTimeInterval(86_400)).id != a.id, "No UTC reset")
            try check(try round(SongClipCatalog(version: 2, clips: clips)).id != a.id, "Catalog revisions share saves")
        }
        await run("exact frame interval rounds inward and rejects invalid bounds") {
            let range = try SongFrameRange(startSeconds: 1.005, durationSeconds: 0.5, sampleRate: 100, fileFrames: 1_000)
            try check(range.start == 101 && range.count == 49, "Segment escaped approved interval")
            for (start, length, rate, frames) in [(0.0, 1.0, 100.0, Int64(99)), (-1, 1, 100, 1_000),
                (0, 1, 0, 1_000), (0, 31, 100, 5_000), (0, 0.001, 100, 5_000), (.infinity, 1, 100, 5_000)] {
                try rejects { _ = try SongFrameRange(startSeconds: start, durationSeconds: length, sampleRate: rate, fileFrames: frames) }
            }
        }
        await run("completed clip unlocks one answer and spoiler-free sharing") {
            let backend = SilentBackend(), s = session(backend)
            try check(!s.answer(clips[0].id) && s.shareText == nil, "Answered before listening")
            s.listen(); s.listen()
            try check(!s.canAnswer, "Loading unlocked answer")
            try await eventually { backend.starts == 1 }
            try check(!s.canAnswer && backend.range?.count == 49, "Playing unlocked answer or wrong interval")
            backend.completed?()
            try check(s.canAnswer && !s.answer("unknown"), "Completion or invalid choice handling")
            try check(s.answer(s.round!.clip.id) && !s.answer(s.round!.clip.id) && s.isCorrect, "Duplicate or wrong score")
            let shared = s.shareText!
            try check(shared.contains("🟩 1/1") && !clips.contains(where: { shared.contains($0.title) || shared.contains($0.id) }), "Share leaked answer")
            s.listen(); try await eventually { backend.starts == 2 }; backend.completed?()
            try check(s.phase == .reveal && s.shareText == shared, "Replay changed result")
        }
        await run("first answer persists separately and invalid stored choice resets") {
            let suite = "song-riff-silent-tests-\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            // This ephemeral suite never touches the app's defaults domain.
            let oldKey = "dailyRiff.v1.20761", oldValue = Data("existing-result".utf8)
            defaults.set(oldValue, forKey: oldKey)
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = SongGuessingStore(defaults: defaults), backend = SilentBackend(), s = session(backend, store: store)
            s.listen(); try await eventually { backend.starts == 1 }; backend.completed?()
            let wrong = s.round!.choices.first { $0.id != s.round!.clip.id }!.id
            try check(s.answer(wrong) && !s.isCorrect, "Wrong answer not recorded")
            store.save(answer: s.round!.clip.id, for: s.round!)
            let restored = session(SilentBackend(), store: store)
            try check(restored.phase == .reveal && restored.answerID == wrong && restored.shareText!.contains("0/1"), "Result replaced")
            try check(defaults.data(forKey: oldKey) == oldValue, "Daily Riff save modified")
            defaults.set("removed-choice", forKey: s.round!.id)
            try check(session(SilentBackend(), store: store).phase == .listen, "Corrupt save accepted")
        }
        await run("pause, stop and late callbacks never unlock an answer") {
            let backend = SilentBackend(), s = session(backend)
            s.listen(); try await eventually { backend.starts == 1 }
            let stale = backend.completed
            s.pause(); stale?(); s.resume()
            try check(!s.canAnswer && backend.stops > 0 && backend.starts == 1, "Pause auto-resumed or stale unlocked")
            s.listen(); try await eventually { backend.starts == 2 }; stale?()
            try check(!s.canAnswer, "Old generation completed new listen")
            backend.completed?(); try check(s.canAnswer, "New completion lost")
            s.stop(); try check(!s.canAnswer, "Stop retained unlocked guess")
        }
        await run("cancelled asynchronous preparation is discarded") {
            var loader: CheckedContinuation<any SongClipPlaybackBackend, Error>?
            let backend = SilentBackend()
            let player = SongClipPlayer(now: { date }, makeBackend: { _ in try await withCheckedThrowingContinuation { loader = $0 } })
            var callbacks = 0
            player.play(try round()) { _ in callbacks += 1 }
            try await eventually { loader != nil }; player.cancel(); loader!.resume(returning: backend)
            try await eventually { backend.stops == 1 }
            try check(backend.starts == 0 && callbacks == 0 && player.state == .idle, "Cancelled load started")
        }
        await run("rights are rechecked before and after preparation") {
            var now = date, factories = 0, failures = 0
            let expiring = try round(catalog { $0.rights.expiresAt = date.addingTimeInterval(1) })
            let backend = SilentBackend()
            let player = SongClipPlayer(now: { now }, makeBackend: { _ in factories += 1; now = date.addingTimeInterval(2); return backend })
            player.play(expiring) { if case .failure = $0 { failures += 1 } }
            try await eventually { failures == 1 }
            try check(backend.starts == 0 && backend.stops == 1, "Expired during load but played")
            player.play(expiring) { if case .failure = $0 { failures += 1 } }
            try await eventually { failures == 2 }
            try check(factories == 1, "Prepared already expired rights")
        }
        await run("load and playback failures remain retryable without answers") {
            let backend = SilentBackend(); backend.failStart = true
            let s = session(backend)
            s.listen(); try await eventually { s.player.state == .failed }
            try check(!s.canAnswer && s.phase == .listen && backend.stops > 0, "Start failure unlocked answer")
            backend.failStart = false; s.listen(); try await eventually { backend.starts == 2 }; backend.completed?()
            try check(s.canAnswer && s.player.errorMessage == nil, "Retry failed")
            s.stop()
            let missing = SongClipPlayer(now: { date }, makeBackend: { _ in throw SongPlaybackError.missingAsset })
            missing.play(try round()) { _ in }
            try await eventually { missing.state == .failed }
            try check(!missing.isBusy, "Missing asset stuck loading")
            let cancelledLoader = SongClipPlayer(now: { date }, makeBackend: { _ in throw CancellationError() })
            cancelledLoader.play(try round()) { _ in }
            try await eventually { cancelledLoader.state == .failed }
        }
        await run("invalid prepared file cleans up without playback") {
            let backend = SilentBackend(); backend.frameLength = 1
            let player = SongClipPlayer(now: { date }, makeBackend: { _ in backend })
            player.play(try round()) { _ in }
            try await eventually { player.state == .failed }
            try check(backend.starts == 0 && backend.stops == 1, "Bad file not cleaned up")
        }
        await run("missing completion times out and late success is ignored") {
            let backend = SilentBackend(), player = SongClipPlayer(now: { date }, makeBackend: { _ in backend })
            var failures = 0, successes = 0
            player.play(try round(catalog { $0.durationSeconds = 0.02 })) {
                switch $0 { case .success: successes += 1; case .failure: failures += 1 }
            }
            try await Task.sleep(for: .milliseconds(2_100))
            backend.completed?()
            try check(failures == 1 && successes == 0 && player.state == .failed && backend.stops == 1, "Timeout accepted late callback")
        }
        print(String(data: try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
        if results.contains(where: { $0["status"] == "failed" }) { exit(1) }
        print("PASS: \(results.count) silent Song Riff checks; no audio backend or recording loaded.")
    }
}
