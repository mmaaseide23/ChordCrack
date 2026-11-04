import Foundation
import Combine

struct SongFrameRange: Equatable {
    let start: Int64
    let count: UInt32
    init(startSeconds: Double, durationSeconds: Double, sampleRate: Double, fileFrames: Int64) throws {
        guard startSeconds.isFinite, durationSeconds.isFinite, sampleRate.isFinite,
              startSeconds >= 0, durationSeconds > 0, durationSeconds <= 30, sampleRate > 0,
              fileFrames > 0 else { throw SongPlaybackError.invalidSegment }
        // Round inward, never play a sample outside the approved interval.
        let first = ceil(startSeconds * sampleRate)
        let end = floor((startSeconds + durationSeconds) * sampleRate)
        guard first.isFinite, end.isFinite, first < Double(Int64.max), end < Double(Int64.max),
              end <= Double(fileFrames), end > first, end - first <= Double(UInt32.max)
        else { throw SongPlaybackError.invalidSegment }
        start = Int64(first); count = UInt32(end - first)
    }
}

enum SongPlaybackError: Error { case invalidSegment, missingAsset, wrongAsset, uncleared, unavailable, timeout }

@MainActor protocol SongClipPlaybackBackend: AnyObject {
    var sampleRate: Double { get }
    var frameLength: Int64 { get }
    func play(_ range: SongFrameRange, completion: @escaping () -> Void) throws
    func stop()
}

/// No URL downloads or shared chord cache. The factory is injected for silent tests.
@MainActor final class SongClipPlayer: ObservableObject {
    enum State { case idle, loading, playing, failed }
    @Published private(set) var state: State = .idle
    @Published private(set) var errorMessage: String?
    private let makeBackend: (SongClip) async throws -> any SongClipPlaybackBackend
    private let now: () -> Date
    private var backend: (any SongClipPlaybackBackend)?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var completion: ((Result<Void, Error>) -> Void)?
    var isBusy: Bool { state == .loading || state == .playing }

    init(now: @escaping () -> Date = Date.init,
         makeBackend: ((SongClip) async throws -> any SongClipPlaybackBackend)? = nil) {
        self.now = now
        self.makeBackend = makeBackend ?? { clip in
            #if os(iOS)
            return try BundledSongClipBackend(clip: clip)
            #else
            throw SongPlaybackError.unavailable
            #endif
        }
    }

    func play(_ round: ClearedSongRound, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isBusy else { return }
        cancel()
        let token = generation
        self.completion = completion
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let clip = round.clip
                guard clip.rights.permits(territory: round.territory, now: now(), seconds: clip.durationSeconds)
                else { throw SongPlaybackError.uncleared }
                let prepared = try await makeBackend(clip)
                guard token == generation, !Task.isCancelled else { prepared.stop(); return }
                backend = prepared
                let range = try SongFrameRange(startSeconds: clip.startSeconds, durationSeconds: clip.durationSeconds,
                                               sampleRate: prepared.sampleRate, fileFrames: prepared.frameLength)
                // Approval can expire while an asynchronous loader is preparing the file.
                guard clip.rights.permits(territory: round.territory, now: now(), seconds: clip.durationSeconds)
                else { throw SongPlaybackError.uncleared }
                state = .playing
                try prepared.play(range) { [weak self] in self?.finish(.success(()), token: token) }
                // Safety timeout only; the native player schedules exactly range.count frames.
                try await Task.sleep(for: .seconds(clip.durationSeconds + 2))
                finish(.failure(SongPlaybackError.timeout), token: token)
            } catch {
                // A cancelled generation is ignored by finish. A loader that independently
                // throws CancellationError must still leave a retryable, non-loading state.
                finish(.failure(error), token: token)
            }
        }
    }
    func cancel() {
        generation = UUID()
        task?.cancel(); task = nil
        backend?.stop(); backend = nil
        completion = nil
        state = .idle; errorMessage = nil
    }
    private func finish(_ result: Result<Void, Error>, token: UUID) {
        guard token == generation else { return }
        let callback = completion
        cancel()
        if case .failure = result {
            state = .failed
            errorMessage = "This clip couldn’t finish. Try listening again."
        }
        callback?(result)
    }
}
