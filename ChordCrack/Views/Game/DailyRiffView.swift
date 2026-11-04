import SwiftUI
import AVFoundation

struct DailyRiffView: View {
    @StateObject private var session: DailyRiffSession

    init() {
        let store = DesignDemo.isEnabled ? DailyRiffStore.preview : DailyRiffStore(defaults: .standard)
        #if DEBUG
        // Explicit, silent UI fixtures; never change the normal device result or Release behavior.
        if DesignDemo.isEnabled && ProcessInfo.processInfo.arguments.contains("--daily-riff-recap") {
            let puzzle = DailyRiffPuzzle()
            let answers = puzzle.rounds.enumerated().map { $0.offset == 1 ? -1 : $0.element.correctIndex }
            store.save(.init(answers: answers, pendingReveal: false), for: puzzle)
        }
        #endif
        _session = StateObject(wrappedValue: DailyRiffSession(store: store))
    }

    var body: some View { DailyRiffContent(session: session, audio: session.audio) }
}

private struct DailyRiffContent: View {
    @ObservedObject var session: DailyRiffSession
    @ObservedObject var audio: AudioManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    @AccessibilityFocusState private var feedbackFocused: Bool
    private let colors = [ColorTheme.primaryGreen, ColorTheme.barre, ColorTheme.progression]
    private let names = ["Feel", "Match", "Switch"]
    private var accent: Color { colors[session.roundIndex] }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        masthead
                        if session.phase == .recap { recap }
                        else {
                            progress
                            if session.isPaused { paused }
                            else if session.phase == .reveal { feedback }
                            else { puzzle }
                        }
                        Text("Synthesized chords · Saved on this device\nNew set at 00:00 UTC · No XP or leaderboard")
                            .font(.caption).foregroundStyle(ColorTheme.textSecondary)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                    .padding(22).frame(maxWidth: 620).frame(maxWidth: .infinity).id("top")
                }
                .onChange(of: session.phase) { _, phase in
                    if phase != .guess { proxy.scrollTo("top", anchor: .top) }
                    feedbackFocused = phase == .reveal || phase == .recap
                }
                .onChange(of: session.isPaused) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
            .background(ColorTheme.background.ignoresSafeArea())
            .foregroundStyle(ColorTheme.textPrimary)
            .navigationTitle("Daily Riff").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { session.stop(); dismiss() }.accessibilityIdentifier("riff.close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if session.phase != .recap && !session.isPaused {
                        Button { session.pause() } label: { Image(systemName: "pause.circle") }
                            .accessibilityLabel("Pause Daily Riff").accessibilityIdentifier("riff.pause")
                    }
                }
            }
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

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(session.puzzle.dateLabel) · UTC").font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(ColorTheme.primaryGreen)
            if !textSize.isAccessibilitySize {
                Text(session.phase == .recap ? "That’s your riff." : "Same day. Same sounds.")
                    .font(.title.bold()).fixedSize(horizontal: false, vertical: true)
                Text("Three puzzles. One shared daily set.")
                    .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    let answered = index < session.answers.count
                    VStack(spacing: 8) {
                        Image(systemName: answered ? (session.answers[index] == session.puzzle.rounds[index].correctIndex ? "checkmark" : "minus") : ["ear", "music.note", "arrow.triangle.swap"][index])
                            .font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(answered || index == session.roundIndex ? ColorTheme.background : colors[index])
                            .background(answered || index == session.roundIndex ? colors[index] : ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 13))
                        if !textSize.isAccessibilitySize { Text(names[index]).font(.caption.weight(.semibold)) }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Puzzle \(index + 1), \(names[index]), \(answered ? (session.answers[index] == session.puzzle.rounds[index].correctIndex ? "correct" : "missed") : index == session.roundIndex ? "current" : "up next")")
                }
            }
            Text("Puzzle \(session.roundIndex + 1) of 3 · \(names[session.roundIndex])")
                .font(.subheadline.weight(.semibold)).foregroundStyle(accent).accessibilityIdentifier("riff.round")
        }
    }

    private var puzzle: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(session.round.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Text(session.round.instruction).font(.body).foregroundStyle(ColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            primaryButton(listenTitle, symbol: audio.isPlaying ? "waveform" : "play.fill", id: "riff.listen") { session.listen() }
                .disabled(!session.canListen)
            audioError
            if session.round.references.isEmpty {
                ForEach(session.round.choices.indices, id: \.self) { index in answerButton(index) }
            } else {
                Text("Compare the references").font(.headline)
                ForEach(session.round.choices.indices, id: \.self) { index in
                    VStack(spacing: 10) {
                        Button { session.reference(index) } label: {
                            Label("Hear \(session.round.choices[index])", systemImage: "play.circle")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }.disabled(!session.canListen).tint(accent)
                            .accessibilityIdentifier("riff.reference.\(index)")
                        answerButton(index)
                    }.padding(12).background(ColorTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            Text(session.phase == .guess ? "One answer counts. Replays are free." : "Choices unlock after the mystery finishes.")
                .font(.caption).foregroundStyle(ColorTheme.textSecondary)
            Button("Skip this puzzle · counts as a miss") { session.skip() }
                .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44).disabled(session.isBusy)
                .accessibilityIdentifier("riff.skip")
        }
    }

    private var listenTitle: String {
        audio.isLoading ? "Preparing sounds…" : audio.isPlaying ? "Listening…" : audio.errorMessage != nil ? "Try listening again" : session.phase == .guess ? "Replay the mystery" : "Play the mystery"
    }

    private func answerButton(_ index: Int) -> some View {
        Button { session.answer(index) } label: {
            Text(session.round.kind == .match ? "Choose \(session.round.choices[index])" : session.round.choices[index])
                .font(.headline).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30).padding(14)
                .foregroundStyle(session.canAnswer ? ColorTheme.textPrimary : ColorTheme.textSecondary)
                .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(session.canAnswer ? accent : ColorTheme.separator, lineWidth: 1))
        }.buttonStyle(.plain).disabled(!session.canAnswer).accessibilityIdentifier("riff.answer.\(index)")
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(session.lastWasCorrect ? "Right on." : session.answers.last == -1 ? "One for next time." : "A new sound to remember.",
                  systemImage: session.lastWasCorrect ? "checkmark.circle.fill" : "ear.badge.waveform")
                .font(.title2.bold()).foregroundStyle(session.lastWasCorrect ? ColorTheme.primaryGreen : ColorTheme.barre)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityFocused($feedbackFocused).accessibilityIdentifier("riff.feedback")
            Text(session.round.explanation).font(.body).fixedSize(horizontal: false, vertical: true)
            if let answer = session.answers.last, answer >= 0, !session.lastWasCorrect {
                Text("You chose: \(session.round.choices[answer])").font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }
            Button { session.listen() } label: {
                Label(audio.isPlaying ? "Listening…" : "Hear the reveal", systemImage: "play.circle")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
            }.disabled(!session.canListen).tint(accent).accessibilityIdentifier("riff.replay")
            audioError
            primaryButton(session.answers.count == 3 ? "See my result" : "Next puzzle", symbol: "arrow.right", id: "riff.next") { session.next() }
        }.padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var recap: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(session.correctCount) / 3").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityLabel("\(session.correctCount) of 3 correct")
                    .accessibilityIdentifier("riff.score").accessibilityFocused($feedbackFocused)
                Text(session.tiles).font(.largeTitle).accessibilityHidden(true)
                Text(session.correctCount == 3 ? "Three for three. Nicely heard." : "A little listening, a little discovery.")
                    .font(.headline).fixedSize(horizontal: false, vertical: true)
                Text("Green = correct · Yellow = missed or skipped")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(ColorTheme.background).padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTheme.primaryGreen, in: RoundedRectangle(cornerRadius: 24))
            if let text = session.shareText {
                ShareLink(item: text) {
                    Label("Share my riff", systemImage: "square.and.arrow.up")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(ColorTheme.background)
                        .background(ColorTheme.barre, in: RoundedRectangle(cornerRadius: 28))
                }.accessibilityIdentifier("riff.share")
                Text("Just the date and your score. The answers stay here.")
                    .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(context.date >= session.puzzle.nextDate ? "A new Daily Riff is ready. Return Home to play it." : "Your result is saved. A new riff arrives at 00:00 UTC.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            }
            Button("Back to Home") { dismiss() }.font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityIdentifier("riff.home")
        }
    }

    private var paused: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your riff can wait.").font(.title2.bold())
            Text("Audio is stopped. Your answers are saved. Listen again when you’re ready.")
                .foregroundStyle(ColorTheme.textSecondary)
            primaryButton("Resume riff", symbol: "play.fill", id: "riff.resume") { session.resume() }
        }.padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private var audioError: some View {
        if let error = audio.errorMessage {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.subheadline).foregroundStyle(ColorTheme.barre).accessibilityIdentifier("riff.audio-error")
        }
    }
    private func primaryButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30).padding(14)
                .foregroundStyle(ColorTheme.background).background(accent, in: RoundedRectangle(cornerRadius: 28))
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}
