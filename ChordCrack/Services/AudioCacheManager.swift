import Foundation

/// Manages persistent disk caching of audio files for offline playback.
/// Audio files are stored in the app's Caches directory under "ChordAudio/".
/// Files persist across app launches but may be purged by the system under storage pressure.
final class AudioCacheManager {
    static let shared = AudioCacheManager()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default

    /// Total number of unique audio files across all chords
    private(set) var totalExpectedFiles: Int = 0

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = caches.appendingPathComponent("ChordAudio", isDirectory: true)

        // Create cache directory if needed
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        // Calculate total expected files
        totalExpectedFiles = calculateTotalExpectedFiles()
    }

    // MARK: - Cache Operations

    /// Returns cached audio data for a file, or nil if not cached.
    func cachedData(for fileName: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    /// Saves audio data to the disk cache.
    func cacheData(_ data: Data, for fileName: String) {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Whether a specific file is cached.
    func isCached(_ fileName: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    /// Number of currently cached audio files.
    var cachedFileCount: Int {
        let contents = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        return contents.filter { $0.hasSuffix(".m4a") }.count
    }

    /// Total size of cached audio files in bytes.
    var cacheSizeBytes: Int64 {
        let contents = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        var total: Int64 = 0
        for file in contents {
            let path = cacheDirectory.appendingPathComponent(file).path
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    /// Human-readable cache size string.
    var cacheSizeString: String {
        let bytes = cacheSizeBytes
        if bytes < 1024 * 1024 {
            return String(format: "%.0f KB", Double(bytes) / 1024.0)
        }
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    }

    /// Clears the entire audio cache.
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Whether all chords have their audio files cached.
    var isFullyCached: Bool {
        return cachedFileCount >= totalExpectedFiles && totalExpectedFiles > 0
    }

    /// Progress of caching (0.0 to 1.0).
    var cacheProgress: Double {
        guard totalExpectedFiles > 0 else { return 0 }
        return min(Double(cachedFileCount) / Double(totalExpectedFiles), 1.0)
    }

    // MARK: - Bulk Download

    /// Returns all unique audio file names needed across all chords.
    func allAudioFileNames() -> [String] {
        var fileNames = Set<String>()
        for chord in ChordType.allCases {
            for fileName in chord.getStringFiles() {
                fileNames.insert(fileName)
            }
        }
        return Array(fileNames).sorted()
    }

    /// Returns file names that are NOT yet cached.
    func uncachedFileNames() -> [String] {
        return allAudioFileNames().filter { !isCached($0) }
    }

    /// Downloads all uncached audio files. Calls progress handler with (completed, total).
    /// Returns the number of successfully downloaded files.
    @discardableResult
    func downloadAllUncached(progress: @escaping (Int, Int) -> Void) async -> Int {
        let uncached = uncachedFileNames()
        let total = uncached.count

        guard total > 0 else {
            progress(0, 0)
            return 0
        }

        var completedSoFar = 0
        let batchSize = 4 // Download 4 at a time

        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, total)
            let batch = Array(uncached[batchStart..<batchEnd])

            let results = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
                for fileName in batch {
                    group.addTask {
                        return await self.downloadAndCache(fileName: fileName)
                    }
                }
                var batchCompleted = 0
                for await _ in group {
                    batchCompleted += 1
                }
                return batchCompleted
            }

            completedSoFar += results
            progress(completedSoFar, total)
        }

        return completedSoFar
    }

    /// Downloads a single audio file and caches it.
    private func downloadAndCache(fileName: String) async -> Bool {
        let urlString = "https://raw.githubusercontent.com/mmaaseide23/Chordle_Assets/main/\(fileName)"
        guard let url = URL(string: urlString) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count > 100 else {
                return false
            }
            cacheData(data, for: fileName)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func calculateTotalExpectedFiles() -> Int {
        var fileNames = Set<String>()
        for chord in ChordType.allCases {
            for fileName in chord.getStringFiles() {
                fileNames.insert(fileName)
            }
        }
        return fileNames.count
    }
}
