import Foundation

/// An opt-in, DEBUG-only local preview. It never uses an account or remote audio.
/// Release builds ignore all design-preview launch arguments.
enum DesignDemo {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--design-demo") ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
        false
        #endif
    }

    static var isEmpty: Bool {
        isEnabled && ProcessInfo.processInfo.arguments.contains("--design-empty")
    }

    /// PCM WAV generated in memory from the string/fret filenames already used by the app.
    /// These are synthetic reference tones, not recordings or a production sound replacement.
    static func stringTone(named fileName: String) -> Data? {
        let pieces = fileName.replacingOccurrences(of: ".m4a", with: "").components(separatedBy: "_fret")
        let openStrings: [String: Double] = ["E2": 82.41, "A3": 110, "D3": 146.83, "G3": 196, "B4": 246.94, "E4": 329.63]
        guard pieces.count == 2, let base = openStrings[pieces[0]], let fret = Double(pieces[1]) else { return nil }
        let frequency = base * pow(2, fret / 12)
        let sampleRate = 22_050
        let sampleCount = sampleRate
        var samples = Data(capacity: sampleCount * 2)
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let attack = min(time * 150, 1)
            let envelope = attack * exp(-time * 4)
            let wave = sin(2 * .pi * frequency * time) + 0.25 * sin(4 * .pi * frequency * time)
            var value = Int16(wave * envelope * 4_500).littleEndian
            withUnsafeBytes(of: &value) { samples.append(contentsOf: $0) }
        }
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func integer<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        text("RIFF"); integer(UInt32(36 + samples.count)); text("WAVEfmt ")
        integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1))
        integer(UInt32(sampleRate)); integer(UInt32(sampleRate * 2))
        integer(UInt16(2)); integer(UInt16(16)); text("data"); integer(UInt32(samples.count))
        data.append(samples)
        return data
    }
}
