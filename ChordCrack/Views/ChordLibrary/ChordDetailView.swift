import SwiftUI

struct ChordDetailView: View {
    let chord: ChordType
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showFingers = true
    @State private var activeAudioTitle: String?
    private let stringNames = ["E4", "B4", "G3", "D3", "A3", "E2"]
    private let stringLabels = ["High E", "B", "G", "D", "A", "Low E"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                fretboard
                playback
                strings
                information
            }
            .padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle(chord.displayName).navigationBarTitleDisplayMode(.inline)
        .tint(ColorTheme.primaryGreen)
        .onDisappear { audioManager.resetForNewRound() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(chord.displayName).font(.largeTitle.weight(.bold)).foregroundStyle(chord.category.color)
                .fixedSize(horizontal: false, vertical: true)
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
                Label(chord.category.displayName, systemImage: chord.category.icon)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(chord.category.color)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(chord.category.color.opacity(0.15), in: Capsule())
                Text(chord.difficultyLevel).font(.subheadline.weight(.semibold)).foregroundStyle(ColorTheme.textSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(ColorTheme.secondaryBackground, in: Capsule())
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
    }

    private var fretboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())) {
                Text("Finger Positions").font(.headline).foregroundStyle(ColorTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showFingers.toggle() }
                } label: {
                    Label(showFingers ? "Hide" : "Show", systemImage: showFingers ? "eye" : "eye.slash")
                        .font(.subheadline).foregroundStyle(ColorTheme.primaryGreen).frame(minHeight: 44)
                }.accessibilityLabel(showFingers ? "Hide finger positions" : "Show finger positions")
            }
            GuitarNeckView(chord: chord, currentAttempt: showFingers ? 5 : 1, jumbledPositions: [], revealedFingerIndex: -1)
                .accessibilityLabel("Fretboard for \(chord.displayName). String details follow below.")
        }
        .padding(16).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(chord.category.color.opacity(0.2), lineWidth: 1))
    }

    private var playback: some View {
        VStack(alignment: .leading, spacing: 14) {
            StudioSectionHeading(title: "Listen", subtitle: "Replay the chord, or pick out the individual notes.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 145), spacing: 10)], spacing: 10) {
                playButton("Full Chord", icon: "play.fill", hint: .chordNoFingers, option: .chord)
                playButton("Slow Strum", icon: "waveform", hint: .chordSlow, option: .chord)
                playButton("Individual", icon: "music.note.list", hint: .individualStrings, option: .individual)
                playButton("Bass Notes", icon: "speaker.wave.1", hint: .audioOptions, option: .bass)
                playButton("Treble Notes", icon: "speaker.wave.3", hint: .audioOptions, option: .treble)
            }
            if audioManager.isLoading {
                ProgressView("Loading audio").tint(ColorTheme.primaryGreen).foregroundStyle(ColorTheme.textSecondary)
            }
            if let error = audioManager.errorMessage {
                Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(ColorTheme.error)
            }
        }
    }

    private func playButton(_ title: String, icon: String, hint: GameManager.HintType, option: GameManager.AudioOption) -> some View {
        let active = audioManager.isPlaying && activeAudioTitle == title
        return Button {
            // Reference listening is replayable; the one-listen rule belongs to scored attempts.
            audioManager.resetForNewAttempt()
            activeAudioTitle = title
            audioManager.playChord(chord, hintType: hint, audioOption: option)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: active ? "waveform" : icon).font(.body)
                Text(title).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(active ? ColorTheme.background : chord.category.color)
            .padding(16).frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(active ? chord.category.color : chord.category.color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(StudioPressStyle()).disabled(audioManager.isLoading)
        .accessibilityLabel("Play \(title)")
        .accessibilityIdentifier("detail.play.\(title)")
    }

    private var strings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("String details").font(.title3.weight(.semibold)).foregroundStyle(ColorTheme.textPrimary)
            ForEach(Array(stringNames.enumerated()), id: \.offset) { index, name in
                let position = chord.fingerPositions.first { $0.string == name }
                HStack {
                    Text(stringLabels[index]).font(.body.weight(.medium)).foregroundStyle(ColorTheme.textPrimary)
                    Spacer()
                    if let position {
                        Text(position.fret == 0 ? "Open" : "Fret \(position.fret)")
                            .font(.body.monospacedDigit()).foregroundStyle(ColorTheme.primaryGreen)
                    } else {
                        Label("Muted", systemImage: "xmark").font(.body).foregroundStyle(ColorTheme.textSecondary)
                    }
                }.padding(.vertical, 5).accessibilityElement(children: .combine)
            }
        }.padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About this chord").font(.title3.weight(.semibold)).foregroundStyle(ColorTheme.textPrimary)
            infoRow("Category", chord.category.displayName)
            infoRow("Difficulty", chord.difficultyLevel)
            infoRow("Strings used", "\(chord.fingerPositions.count) of 6")
            infoRow("Highest fret", "\(chord.fingerPositions.map(\.fret).max() ?? 0)")
            if chord.isAllowedInDailyChallenge {
                Label("Used in Daily Challenge", systemImage: "calendar")
                    .font(.subheadline).foregroundStyle(ColorTheme.primaryGreen)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value).font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
    }
}
