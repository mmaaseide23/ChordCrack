import Foundation
import Testing
@testable import ChordCrack

@Suite(.serialized)
struct ChordCrackTests {
    @Test func syntheticPreviewAudioIsAPlayablePCMContainer() throws {
        let wave = try #require(DesignDemo.stringTone(named: "E2_fret0.m4a"))
        #expect(String(data: wave.prefix(4), encoding: .ascii) == "RIFF")
        #expect(String(data: wave[8..<12], encoding: .ascii) == "WAVE")
        #expect(wave.count == 44 + 22_050 * 2)
        #expect(DesignDemo.stringTone(named: "invalid.m4a") == nil)
        #expect(DesignDemo.stringTone(named: "E2_fret12.m4a") != wave)
    }

    @Test func everyChordCanProduceLocalPreviewAudio() {
        for chord in ChordType.allCases {
            #expect(!chord.getStringFiles().isEmpty)
            for name in chord.getStringFiles() {
                #expect(DesignDemo.stringTone(named: name) != nil)
            }
        }
    }
    @Test @MainActor func failedAudioCanRetryAndRepeatInANewRound() async throws {
        var fail = true
        let audio = AudioManager { name in
            if fail { throw URLError(.notConnectedToInternet) }
            return try #require(DesignDemo.stringTone(named: name))
        }
        audio.playChord(.aMajor)
        try await waitUntil { !audio.isLoading }
        #expect(audio.errorMessage != nil)
        #expect(!audio.hasPlayedForCurrentChord(.aMajor))
        fail = false
        audio.playChord(.aMajor)
        try await waitUntil { audio.isPlaying || audio.errorMessage != nil }
        #expect(audio.isPlaying)
        #expect(audio.hasPlayedForCurrentChord(.aMajor))
        audio.resetForNewRound()
        #expect(!audio.hasPlayedForCurrentChord(.aMajor))
        #expect(!audio.isPlaying)
        audio.playChord(.aMajor)
        try await waitUntil { audio.isPlaying || audio.errorMessage != nil }
        #expect(audio.isPlaying)
        audio.resetForNewRound()
    }

    @Test @MainActor func resettingDuringLoadDiscardsLateAudio() async throws {
        let audio = AudioManager { name in
            // A loader which ignores cancellation emulates a late cache/network result.
            try? await Task.sleep(for: .milliseconds(200))
            return try #require(DesignDemo.stringTone(named: name))
        }
        audio.playChord(.aMajor)
        await Task.yield()
        audio.resetForNewRound()
        try await Task.sleep(for: .milliseconds(350))
        #expect(!audio.isLoading)
        #expect(!audio.isPlaying)
        #expect(audio.errorMessage == nil)
        #expect(!audio.hasPlayedForCurrentChord(.aMajor))
    }

    @Test @MainActor func corruptAudioDoesNotConsumeAListen() async throws {
        let audio = AudioManager { _ in Data("not audio".utf8) }
        audio.playChord(.aMajor)
        try await waitUntil { !audio.isLoading }
        #expect(audio.errorMessage != nil)
        #expect(!audio.isPlaying)
        #expect(!audio.hasPlayedForCurrentChord(.aMajor))
    }

    @MainActor private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Timed out waiting for audio state")
    }
}
