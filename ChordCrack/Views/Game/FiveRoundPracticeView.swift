import SwiftUI
import AVFoundation
import CoreHaptics

/// A disposable five-round exercise using the original app's palette and components.
struct FiveRoundPracticeView: View {
    @StateObject private var session = FiveRoundPracticeSession()
    var body: some View { FiveRoundPracticeContent(session: session, audio: session.audio) }
}

private struct FiveRoundPracticeContent: View {
    @ObservedObject var session: FiveRoundPracticeSession
    @ObservedObject var audio: AudioManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var showOptions = false
    @State private var hapticsEnabled = UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
    @AccessibilityFocusState private var feedbackFocused: Bool
    @AccessibilityFocusState private var listenFocused: Bool
    private var reduceMotion: Bool { systemReduceMotion || (DesignDemo.isEnabled && ProcessInfo.processInfo.arguments.contains("--prototype-reduce-motion")) }
    private var accent: Color { ColorTheme.primaryGreen }
    private var busy: Bool { audio.isLoading || audio.isPlaying }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if session.phase == .recap { recap }
                        else {
                            progress
                            if session.isPaused { pauseCard }
                            else if session.phase == .reveal { revealCard }
                            else { listenCard; answers }
                        }
                        Text("Five-round practice · Synthesized chords\nProgress stays in this session.")
                            .font(.caption).foregroundStyle(ColorTheme.textSecondary)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                            .accessibilityIdentifier("prototype.disclosure")
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                    .id("top")
                }
                .onChange(of: session.phase) { _, phase in
                    if phase == .reveal || phase == .recap { proxy.scrollTo("top", anchor: .top) }
                    feedbackFocused = phase == .reveal || phase == .recap
                    listenFocused = phase == .listen
                }
                .onChange(of: session.roundIndex) { _, _ in proxy.scrollTo("top", anchor: .top) }
                .onChange(of: session.isPaused) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
            .background(ColorTheme.background.ignoresSafeArea())
            .foregroundStyle(ColorTheme.textPrimary)
            .navigationTitle(textSize.isAccessibilitySize ? "Practice" : "Five-round practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { session.stop(); dismiss() }.accessibilityIdentifier("prototype.close")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if session.phase != .recap {
                        Button { session.pause() } label: { Image(systemName: "pause.circle") }
                            .accessibilityLabel("Pause practice").accessibilityIdentifier("prototype.pause")
                    }
                    Button { session.pause(); showOptions = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Practice options").accessibilityIdentifier("prototype.options")
                }
            }
            .sheet(isPresented: $showOptions) { options }
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
        }
        .preferredColorScheme(.dark).tint(accent)
    }

    private var progress: some View {
        VStack(spacing: 14) {
            (textSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                Text("Round \(session.roundIndex + 1) of 5").font(.headline)
                    .accessibilityIdentifier("prototype.round")
                if !textSize.isAccessibilitySize { Spacer(minLength: 12) }
                Text("\(session.score) pts").font(.headline.monospacedDigit()).foregroundStyle(accent)
                    .contentTransition(.numericText()).accessibilityIdentifier("prototype.score")
            }
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Capsule().fill(index < session.results.count ? accent : ColorTheme.cardBackground)
                        .frame(height: 5)
                }
            }.accessibilityLabel("\(session.results.count) of 5 rounds complete")
            stringDetail.frame(width: 100)
        }
    }

    private var listenCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Major or minor?").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(session.phase == .guess ? "Trust your ear. Choose the sound you heard." : "Listen first, then choose. Replay if you need it.")
                        .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
                }
                if !textSize.isAccessibilitySize {
                    StudioPickShape().stroke(accent, lineWidth: 2).frame(width: 25, height: 31)
                        .padding(.leading, 8).accessibilityHidden(true)
                }
            }
            primaryButton(audio.isLoading ? "Preparing chord…" : audio.isPlaying ? "Listening…" : audio.errorMessage != nil ? "Retry chord" : session.phase == .guess ? "Listen again" : "Listen to chord",
                          symbol: audio.isPlaying ? "waveform" : "play.fill", id: "prototype.listen") { session.listen() }
                .disabled(busy || !session.soundEnabled)
                .accessibilityFocused($listenFocused)
            if !session.soundEnabled { Text("Chord audio is off. Turn it on in Practice options to listen.").font(.subheadline) }
            audioError
        }.padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var answers: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.phase == .guess ? "What did you hear?" : "Your choices").font(.headline)
            (textSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
                ForEach(FiveRoundPracticeSession.Quality.allCases, id: \.self) { quality in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                            if session.answer(quality) { answerHaptic(correct: session.lastResult?.isCorrect == true) }
                        }
                    } label: {
                        Text(quality.rawValue).font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 58).padding(.horizontal, 10)
                            .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(session.canGuess ? accent.opacity(0.5) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(PracticePressStyle(reduceMotion: reduceMotion)).disabled(!session.canGuess)
                    .opacity(session.canGuess ? 1 : 0.55)
                    .accessibilityIdentifier("prototype.answer.\(quality.rawValue)")
                }
            }
            if session.phase != .guess {
                Text("Answers unlock after the chord finishes.").font(.caption).foregroundStyle(ColorTheme.textSecondary)
            }
        }
    }

    private var revealCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let result = session.lastResult {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "ear.badge.waveform")
                        .font(.title2).foregroundStyle(result.isCorrect ? accent : ColorTheme.barre)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.isCorrect ? "You heard it." : "A little different.").font(.title2.bold())
                        Text("That was \(result.round.name(for: result.round.quality)).")
                            .font(.headline).foregroundStyle(ColorTheme.textSecondary)
                    }.accessibilityElement(children: .combine).accessibilityFocused($feedbackFocused)
                        .accessibilityIdentifier("prototype.feedback")
                    if result.isCorrect && !textSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                        Text("+20").font(.headline.monospacedDigit()).foregroundStyle(accent)
                            .transition(reduceMotion ? .identity : .offset(y: 6).combined(with: .opacity))
                    }
                }
                if result.isCorrect {
                    Text("One more sound in your ear. Ready for the next?").font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
                    replayButton(result.round.quality, title: "Hear it again", id: "prototype.replay.correct")
                } else {
                    Text("Compare the two. In these shapes, one note moves down a fret to make the minor chord.")
                        .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
                    replayButton(result.guess, title: "Your guess", chordName: result.round.name(for: result.guess), id: "prototype.replay.guess")
                    replayButton(result.round.quality, title: "Actual chord", chordName: result.round.name(for: result.round.quality), id: "prototype.replay.correct")
                }
                audioError
                primaryButton(session.roundIndex == 4 ? "See your recap" : "Next round", symbol: "arrow.right", id: "prototype.next") { session.next() }
                Text("Take your time. Move on whenever you’re ready.").font(.caption).foregroundStyle(ColorTheme.textSecondary)
            }
        }.padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(session.lastResult?.isCorrect == true ? 0.55 : 0.2), lineWidth: 1))
    }

    private var stringDetail: some View {
        let motionDisabled = reduceMotion
        return HStack(spacing: 14) {
            VStack(spacing: 5) {
                ForEach(0..<6) { index in
                    Rectangle().fill(accent.opacity(index == 2 ? 0.7 : 0.22)).frame(height: index < 3 ? 1 : 1.5)
                }
            }
            StudioPickShape().fill(accent).frame(width: 18, height: 23)
                .keyframeAnimator(initialValue: 0.0, trigger: session.results.count) { content, value in
                    content.rotationEffect(.degrees(motionDisabled ? 0 : value))
                } keyframes: { _ in
                    LinearKeyframe(-12, duration: 0.10)
                    SpringKeyframe(0, duration: 0.25)
                }
        }.frame(height: 38).accessibilityHidden(true)
    }

    private var recap: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Five rounds, well played.").font(.largeTitle.bold()).accessibilityFocused($feedbackFocused)
                .accessibilityIdentifier("prototype.recap")
            Text("\(session.correctCount) of 5 recognized · \(session.score) points")
                .font(.title3.weight(.semibold)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 12) {
                Text(session.missedPairs.isEmpty ? "A good ear for the difference." : "One thing to take with you").font(.headline)
                Text(session.missedPairs.isEmpty ? "You recognized all five. Try the same set again and listen for the note that changes." : "Spend another listen on \(session.missedPairs.joined(separator: ", ")) major and minor. That small change in the third changes the chord’s character.")
                    .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }.padding(18).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            ForEach(session.results) { result in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "ear")
                        .foregroundStyle(result.isCorrect ? accent : ColorTheme.barre).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(result.id + 1). \(result.round.name(for: result.round.quality))").font(.headline)
                        Text(result.isCorrect ? "Recognized" : "You chose \(result.guess.rawValue.lowercased())").font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
                    }
                }.accessibilityElement(children: .combine)
            }
            primaryButton("Practice this set again", symbol: "arrow.counterclockwise", id: "prototype.restart") { session.restart() }
            Button("Back to Home") { session.stop(); dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var pauseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Take a breath.").font(.title2.bold())
            Text("Your place is saved for this session. Audio has stopped.").font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            primaryButton("Resume practice", symbol: "play.fill", id: "prototype.resume") { session.resume() }
        }.padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var options: some View {
        NavigationStack {
            Form {
                Toggle("Chord audio", isOn: $session.soundEnabled).accessibilityIdentifier("prototype.sound")
                Toggle("Light answer haptics", isOn: $hapticsEnabled).accessibilityIdentifier("prototype.haptics")
                Text("No music or answer sounds. Haptics follow your app preference initially and require a supported iPhone. These options apply only to this practice session.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(textSize.isAccessibilitySize ? "Options" : "Practice options")
            .navigationBarTitleDisplayMode(textSize.isAccessibilitySize ? .inline : .large)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showOptions = false } } }
        }
    }

    @ViewBuilder private var audioError: some View {
        if let error = audio.errorMessage {
            Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(ColorTheme.barre)
        }
    }
    private func primaryButton(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).accessibilityHidden(true)
                Text(title).font(.headline).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
                .frame(maxWidth: .infinity, minHeight: 30).padding(14)
                .foregroundStyle(ColorTheme.background).background(accent, in: RoundedRectangle(cornerRadius: 28))
        }.buttonStyle(PracticePressStyle(reduceMotion: reduceMotion)).accessibilityIdentifier(id)
    }
    private func replayButton(_ quality: FiveRoundPracticeSession.Quality, title: String, chordName: String? = nil, id: String) -> some View {
        Button { session.replay(quality) } label: {
            HStack(spacing: 12) {
                Image(systemName: busy && session.activeReplay == quality ? "waveform" : "play.circle")
                    .font(.system(size: 22)).frame(width: 24).accessibilityHidden(true)
                if let chordName, textSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
                        Text(chordName).font(.headline)
                    }.fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(chordName.map { "\(title) · \($0)" } ?? title).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }.font(.headline).padding(14).frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(accent).background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(PracticePressStyle(reduceMotion: reduceMotion)).disabled(busy || !session.soundEnabled).accessibilityIdentifier(id)
    }
    private func answerHaptic(correct: Bool) {
        guard hapticsEnabled, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if correct { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.45) }
        // Mistakes receive a calm visual explanation, without an error buzz.
    }
}

private struct PracticePressStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
