import SwiftUI

struct ChordDetailView: View {
    let chord: ChordType
    @EnvironmentObject var audioManager: AudioManager
    @State private var showFingers = true

    private let stringNames = ["E4", "B4", "G3", "D3", "A3", "E2"]
    private let stringLabels = ["e (High)", "B", "G", "D", "A", "E (Low)"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Chord header
                chordHeader

                // Guitar neck visualization
                guitarNeckSection

                // Audio playback
                playbackSection

                // Finger positions table
                fingerPositionsSection

                // Chord info
                chordInfoSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(ColorTheme.background)
        .navigationTitle(chord.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chord Header

    private var chordHeader: some View {
        VStack(spacing: 12) {
            // Large chord name
            Text(chord.displayName)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(chord.category.color)

            // Category + difficulty badges
            HStack(spacing: 12) {
                Label(chord.category.displayName, systemImage: chord.category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(chord.category.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(chord.category.color.opacity(0.15))
                    )

                Text(chord.difficultyLevel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ColorTheme.secondaryBackground)
                    )
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Guitar Neck

    private var guitarNeckSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Finger Positions")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showFingers.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showFingers ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 12))
                        Text(showFingers ? "Hide" : "Show")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(chord.category.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(chord.category.color.opacity(0.15))
                    )
                }
            }

            // Reuse the existing GuitarNeckView with fingers always shown
            GuitarNeckView(
                chord: chord,
                currentAttempt: showFingers ? 5 : 1,
                jumbledPositions: [],
                revealedFingerIndex: -1
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(chord.category.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        VStack(spacing: 16) {
            Text("Listen")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                // Full chord button
                playButton(
                    title: "Full Chord",
                    icon: "music.note.list",
                    hintType: .chordNoFingers,
                    audioOption: .chord
                )

                // Slow strum button
                playButton(
                    title: "Slow Strum",
                    icon: "waveform",
                    hintType: .chordSlow,
                    audioOption: .chord
                )

                // Individual strings button
                playButton(
                    title: "Individual",
                    icon: "dot.radiowaves.left.and.right",
                    hintType: .individualStrings,
                    audioOption: .individual
                )
            }

            HStack(spacing: 12) {
                // Bass notes
                playButton(
                    title: "Bass Notes",
                    icon: "speaker.wave.1",
                    hintType: .audioOptions,
                    audioOption: .bass
                )

                // Treble notes
                playButton(
                    title: "Treble Notes",
                    icon: "speaker.wave.3",
                    hintType: .audioOptions,
                    audioOption: .treble
                )
            }

            if audioManager.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading audio...")
                        .font(.system(size: 13))
                        .foregroundColor(ColorTheme.textSecondary)
                }
            }

            if let error = audioManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ColorTheme.error)
                        .font(.caption)
                    Text(error)
                        .foregroundColor(ColorTheme.error)
                        .font(.caption)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTheme.error.opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(chord.category.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func playButton(title: String, icon: String, hintType: GameManager.HintType, audioOption: GameManager.AudioOption) -> some View {
        Button {
            audioManager.playChord(chord, hintType: hintType, audioOption: audioOption)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: audioManager.isPlaying ? "speaker.wave.2.fill" : icon)
                    .font(.system(size: 18))
                    .foregroundColor(chord.category.color)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(chord.category.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(chord.category.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .disabled(audioManager.isLoading)
    }

    // MARK: - Finger Positions Table

    private var fingerPositionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("String Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("String")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 80, alignment: .leading)

                    Text("Fret")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ColorTheme.textSecondary)
                        .frame(width: 50, alignment: .center)

                    Spacer()

                    Text("Status")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ColorTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(ColorTheme.secondaryBackground)

                // String rows
                ForEach(Array(stringNames.enumerated()), id: \.offset) { index, stringName in
                    let position = chord.fingerPositions.first(where: { $0.string == stringName })
                    let isPlayed = position != nil

                    HStack {
                        Text(stringLabels[index])
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ColorTheme.textPrimary)
                            .frame(width: 80, alignment: .leading)

                        Text(isPlayed ? (position!.fret == 0 ? "Open" : "Fret \(position!.fret)") : "-")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(isPlayed ? chord.category.color : ColorTheme.textTertiary)
                            .frame(width: 50, alignment: .center)

                        Spacer()

                        if isPlayed {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(chord.category.color)
                                    .frame(width: 8, height: 8)
                                Text(position!.fret == 0 ? "Open" : "Fretted")
                                    .font(.system(size: 12))
                                    .foregroundColor(ColorTheme.textSecondary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundColor(ColorTheme.textTertiary)
                                Text("Muted")
                                    .font(.system(size: 12))
                                    .foregroundColor(ColorTheme.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    if index < stringNames.count - 1 {
                        Divider()
                            .background(ColorTheme.textTertiary.opacity(0.2))
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorTheme.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(chord.category.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Chord Info

    private var chordInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Chord")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)

            VStack(spacing: 8) {
                infoRow(label: "Category", value: chord.category.displayName, color: chord.category.color)
                infoRow(label: "Difficulty", value: chord.difficultyLevel, color: ColorTheme.textPrimary)
                infoRow(label: "Strings Used", value: "\(chord.fingerPositions.count) of 6", color: ColorTheme.textPrimary)
                infoRow(label: "Highest Fret", value: "\(chord.fingerPositions.map(\.fret).max() ?? 0)", color: ColorTheme.textPrimary)

                if chord.isAllowedInDailyChallenge {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 13))
                            .foregroundColor(ColorTheme.primaryGreen)
                        Text("Used in Daily Challenge")
                            .font(.system(size: 13))
                            .foregroundColor(ColorTheme.primaryGreen)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(chord.category.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func infoRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(ColorTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

#Preview {
    NavigationStack {
        ChordDetailView(chord: .cMajor)
            .environmentObject(AudioManager())
    }
    .preferredColorScheme(.dark)
}
