import Foundation

enum SongRiffFeature {
    // Deliberate release gate. No launch argument, remote flag or preview bypass.
    static let isEnabled = false
}

struct SongRightsEvidence: Codable {
    enum Basis: String, Codable { case unreviewed, publicDomain, licensed }
    var basis: Basis
    var source: URL
    var rationale: String
    var attribution: String
    var licenseURL: URL? = nil
    var modificationNotice: String = ""

    var isDocumented: Bool {
        basis != .unreviewed && source.scheme == "https" && source.host != nil &&
        !rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (basis != .licensed || (!attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            licenseURL?.scheme == "https" && licenseURL?.host != nil &&
            !modificationNotice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }
}

/// Records a reviewed decision; these fields cannot themselves establish legal rights.
struct SongRightsReview: Codable {
    var composition: SongRightsEvidence
    var arrangement: SongRightsEvidence
    var recording: SongRightsEvidence
    var reviewer: String
    var reviewedAt: Date
    var expiresAt: Date?
    var territories: Set<String> // Explicit ISO country codes; no assumed worldwide clearance.
    var permitsCommercialQuiz: Bool
    var permitsBundledExcerpt: Bool
    var permitsAttributionAfterReveal: Bool
    var maximumExcerptSeconds: Double

    func permits(territory: String, now: Date, seconds: Double) -> Bool {
        [composition, arrangement, recording].allSatisfy(\.isDocumented) &&
        !reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && reviewedAt <= now &&
        (expiresAt.map { now < $0 } ?? true) && territory.count == 2 &&
        territory == territory.uppercased() && territories.contains(territory) &&
        permitsCommercialQuiz && permitsBundledExcerpt && permitsAttributionAfterReveal &&
        maximumExcerptSeconds.isFinite && seconds <= maximumExcerptSeconds
    }
}

struct SongClip: Codable, Identifiable {
    enum Kind: String, Codable { case recording, syntheticTestFixture }
    var id: String
    var title: String
    var performer: String
    var kind: Kind
    var bundledFile: String
    var sha256: String // Identifies the exact cleared bytes, not just a song title.
    var startSeconds: Double
    var durationSeconds: Double
    var rights: SongRightsReview

    var isWellFormed: Bool {
        [id, title, performer].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        !bundledFile.isEmpty && !bundledFile.contains("/") && !bundledFile.contains("\\") &&
        !bundledFile.contains("..") && ["wav", "m4a", "caf", "aif", "aiff"].contains((bundledFile as NSString).pathExtension) &&
        sha256.count == 64 && sha256.allSatisfy { "0123456789abcdef".contains($0) } &&
        startSeconds.isFinite && durationSeconds.isFinite && startSeconds >= 0 &&
        durationSeconds > 0 && durationSeconds <= 30 && (startSeconds + durationSeconds).isFinite
    }
}

struct SongClipCatalog {
    static let current = SongClipCatalog(version: 1, clips: []) // No approved song recordings yet.
    enum Use {
        case production
        #if DEBUG
        case syntheticTests
        #endif
    }
    enum Unavailable: Error { case disabled, invalidCatalog, uncleared }
    let version: Int
    let clips: [SongClip]

    func round(date: Date, territory: String, enabled: Bool = SongRiffFeature.isEnabled,
               use: Use = .production) throws -> ClearedSongRound {
        guard enabled else { throw Unavailable.disabled }
        guard version > 0, clips.count >= 3, clips.allSatisfy(\.isWellFormed),
              Set(clips.map(\.id)).count == clips.count,
              Set(clips.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count == clips.count else { throw Unavailable.invalidCatalog }
        let day = Int(floor(date.timeIntervalSince1970 / 86_400))
        let ordered = clips.sorted { $0.id < $1.id }
        let index = ((day % ordered.count) + ordered.count) % ordered.count
        let clip = ordered[index]
        // Do not filter by region: that would silently give different players different daily songs.
        guard clip.rights.permits(territory: territory, now: date, seconds: clip.durationSeconds) else { throw Unavailable.uncleared }
        switch use {
        case .production:
            guard ordered.allSatisfy({ $0.kind == .recording }) else { throw Unavailable.uncleared }
        #if DEBUG
        case .syntheticTests:
            guard ordered.allSatisfy({ $0.kind == .syntheticTestFixture }) else { throw Unavailable.uncleared }
        #endif
        }
        var choices = (0..<3).map { ordered[(index + $0) % ordered.count] }
            .map { ClearedSongRound.Choice(id: $0.id, title: $0.title) }
        choices.swapAt(0, ((day % 3) + 3) % 3)
        return ClearedSongRound(clip: clip, choices: choices, day: day, catalogVersion: version,
                                territory: territory)
    }
}

/// Constructed only by the catalog's gate. Never decode this approval from remote JSON.
struct ClearedSongRound {
    struct Choice: Identifiable { let id: String; let title: String }
    let clip: SongClip
    let choices: [Choice]
    let day: Int
    let catalogVersion: Int
    let territory: String
    fileprivate init(clip: SongClip, choices: [Choice], day: Int, catalogVersion: Int, territory: String) {
        self.clip = clip; self.choices = choices; self.day = day
        self.catalogVersion = catalogVersion; self.territory = territory
    }
    var id: String { "songRiff.v1.catalog\(catalogVersion).\(day)" }
    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: Double(day) * 86_400))
    }
}
