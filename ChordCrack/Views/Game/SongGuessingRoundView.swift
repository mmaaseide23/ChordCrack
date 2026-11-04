import SwiftUI
import AVFoundation

/// Intentionally has no Home/menu entry while the feature and catalog are disabled.
struct SongGuessingRoundView: View {
    @StateObject private var session = SongGuessingSession()
    var body: some View { SongGuessingContent(session: session, player: session.player) }
}

private struct SongGuessingContent: View {
    @ObservedObject var session: SongGuessingSession
    @ObservedObject var player: SongClipPlayer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "music.note.list").font(.largeTitle).foregroundStyle(ColorTheme.warning)
                    if let round = session.round {
                        Text("\(round.dateLabel) · UTC").font(.caption.monospacedDigit())
                        if session.isPaused {
                            Text("Take a beat.").font(.title.bold())
                            Button("Resume") { session.resume() }.buttonStyle(.borderedProminent)
                        } else {
                            if session.phase == .reveal {
                                Text(session.isCorrect ? "You found it!" : "Now you know it.").font(.title.bold())
                                Text(round.clip.title).font(.title2.bold())
                                Text(round.clip.performer).foregroundStyle(ColorTheme.textSecondary)
                                if let share = session.shareText { ShareLink(item: share) { Label("Share result", systemImage: "square.and.arrow.up") } }
                                credits(round.clip)
                            } else {
                                Text("Name that song.").font(.title.bold())
                                Text("Listen to the clip, then choose a title. Your first answer counts.")
                                    .foregroundStyle(ColorTheme.textSecondary)
                            }
                            Button { session.listen() } label: {
                                Label(player.isBusy ? "Playing…" : "Listen to clip", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.borderedProminent).disabled(!session.canListen)
                            if player.isBusy { Button("Stop") { session.stop() } }
                            if let error = player.errorMessage { Text(error).foregroundStyle(ColorTheme.warning) }
                            if session.phase != .reveal {
                                ForEach(round.choices) { choice in
                                    Button(choice.title) { session.answer(choice.id) }
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .buttonStyle(.bordered).disabled(!session.canAnswer)
                                }
                            }
                        }
                    } else {
                        Text("Song rounds are still in the works.").font(.title.bold())
                        Text("There are no cleared song clips available yet. Daily Riff’s chord puzzles are ready to play.")
                            .foregroundStyle(ColorTheme.textSecondary)
                    }
                }.padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background(ColorTheme.background.ignoresSafeArea()).foregroundStyle(ColorTheme.textPrimary)
            .navigationTitle("Song Riff").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { session.stop(); dismiss() } } }
            .onChange(of: scenePhase) { _, value in if value != .active { session.pause() } }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
                if let value = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                   value == AVAudioSession.InterruptionType.began.rawValue { session.pause() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { note in
                if let value = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                   value == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { session.pause() }
            }
            .onDisappear { session.stop() }
        }.preferredColorScheme(.dark).tint(ColorTheme.primaryGreen)
    }

    private func credits(_ clip: SongClip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Credits & sources").font(.headline)
            let evidence = [clip.rights.composition, clip.rights.arrangement, clip.rights.recording]
            ForEach(Array(evidence.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    if !item.attribution.isEmpty { Text(item.attribution).font(.caption) }
                    if !item.modificationNotice.isEmpty { Text(item.modificationNotice).font(.caption) }
                    Link(["Composition", "Arrangement", "Recording"][index], destination: item.source)
                    if let license = item.licenseURL { Link("License", destination: license) }
                }
            }
        }
    }
}
