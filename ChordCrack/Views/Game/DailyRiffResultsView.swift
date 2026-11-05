import SwiftUI

struct DailyRiffResultsView: View {
    @ObservedObject var session: DailyRiffSession
    var close: () -> Void
    @AccessibilityFocusState private var scoreFocused: Bool
    private var count: Int { session.puzzle.rounds.count }
    private var community: DailyRiffCommunity {
        #if DEBUG
        if DesignDemo.isEnabled && ProcessInfo.processInfo.arguments.contains("--daily-riff-community-fixture") {
            return .syntheticPreview(for: session.puzzle)
        }
        if DesignDemo.isEnabled && ProcessInfo.processInfo.arguments.contains("--daily-riff-community-empty") {
            return .waiting
        }
        #endif
        return .unavailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if DesignDemo.isEnabled { Text("PREVIEW RESULT").font(.caption.bold()).foregroundStyle(ColorTheme.barre) }
            scoreCard
            if let share = session.shareText {
                ShareLink(item: share) {
                    Label {
                        Text("Share my riff").fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 20, weight: .semibold))
                    }
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(ColorTheme.background)
                        .background(ColorTheme.barre, in: RoundedRectangle(cornerRadius: 28))
                }.accessibilityIdentifier("riff.share")
                Text(count == 5 ? "Five little squares. No answers spoiled." : "Just your score and result squares. No answers spoiled.")
                    .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }
            communityCard
            VStack(alignment: .leading, spacing: 16) {
                Text("Your listening, round by round").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                ForEach(session.answers.indices, id: \.self) { index in
                    let correct = session.answers[index] == session.puzzle.rounds[index].correctIndex
                    let result = correct ? "Correct" : session.answers[index] == -1 ? "Skipped" : "Missed"
                    HStack(spacing: 12) {
                        Text("\(index + 1)").font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(width: 34, height: 34).background(ColorTheme.surfaceSecondary, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.puzzle.rounds[index].title).font(.headline)
                            Label(result, systemImage: correct ? "checkmark.circle.fill" : "minus.circle")
                                .font(.subheadline).foregroundStyle(correct ? ColorTheme.primaryGreen : ColorTheme.barre)
                        }.fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("riff.result.\(index)")
                    if index < count - 1 { Divider().overlay(ColorTheme.separator) }
                }
            }.padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 22))
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(context.date >= session.puzzle.nextDate ? "A new Daily Riff is ready. Return Home to play it." : "Your first answers are saved on this device. A new riff arrives at 00:00 UTC.")
                    .font(.body).fixedSize(horizontal: false, vertical: true)
            }
            if session.puzzle.contentVersion == 1 {
                Text("You started this original three-round set before the update. Its result stays intact; your next new day has five rounds.")
                    .font(.subheadline).foregroundStyle(ColorTheme.textSecondary)
            }
            Button("Back to Home", action: close).font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityIdentifier("riff.home")
        }.onAppear { scoreFocused = true }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Riff complete").font(.caption.weight(.heavy))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(session.correctCount) / \(count)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityLabel("\(session.correctCount) of \(count) correct")
                .accessibilityIdentifier("riff.score").accessibilityFocused($scoreFocused)
            HStack(spacing: 8) {
                ForEach(session.answers.indices, id: \.self) { index in
                    let correct = session.answers[index] == session.puzzle.rounds[index].correctIndex
                    Image(systemName: correct ? "checkmark" : "minus")
                        .font(.system(size: 18, weight: .bold)).frame(maxWidth: .infinity).frame(height: 36)
                        .background(correct ? ColorTheme.background.opacity(0.13) : ColorTheme.barre, in: RoundedRectangle(cornerRadius: 8))
                }
            }.accessibilityHidden(true)
            Text(session.correctCount == count ? "A perfect riff. Nicely heard." : "New sounds. Sharper ears.")
                .font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
            Text("One point per correct first answer. Replays are free.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(ColorTheme.background).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [ColorTheme.lightGreen, ColorTheme.primaryGreen], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }

    private var communityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text("Today’s community").fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "person.3.fill").font(.system(size: 20, weight: .semibold))
            }
                .font(.title3.bold()).foregroundStyle(ColorTheme.progression).accessibilityAddTraits(.isHeader)
            switch community {
            case .unavailable:
                Text("Community stats aren’t connected yet.").font(.headline)
                    .accessibilityIdentifier("riff.community.unavailable")
                Text("Your result stays on this device. When community stats are available, sharing a result will be your choice.")
                    .font(.body).foregroundStyle(ColorTheme.textSecondary)
            case .waiting:
                Text("Waiting for a bigger crowd").font(.headline).accessibilityIdentifier("riff.community.waiting")
                Text("Totals appear after at least 20 players choose to include a completed riff. Small groups stay hidden.")
                    .foregroundStyle(ColorTheme.textSecondary)
                sampleLabel
            case .summary(let summary):
                if summary.isValid(for: session.puzzle) {
                    sampleLabel
                    Text(summary.participantsLabel).font(.headline)
                    Text("Completed sets · \(session.puzzle.dateLabel) · v\(session.puzzle.contentVersion)")
                        .font(.caption).foregroundStyle(ColorTheme.textSecondary)
                    ForEach(0..<3) { index in
                        VStack(alignment: .leading, spacing: 7) {
                            ViewThatFits(in: .horizontal) {
                                HStack { Text(["0–1 correct", "2–3 correct", "4–5 correct"][index]); Spacer(); Text(summary.bandLabel(index)) }
                                VStack(alignment: .leading) { Text(["0–1 correct", "2–3 correct", "4–5 correct"][index]); Text(summary.bandLabel(index)) }
                            }.font(.subheadline.weight(.semibold))
                            if let value = summary.scoreBands[index] {
                                GeometryReader { space in
                                    RoundedRectangle(cornerRadius: 5).fill(ColorTheme.progression.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 5).fill(ColorTheme.progression)
                                        .frame(width: space.size.width * min(1, Double(value) / Double(summary.participantsLower)))
                                }.frame(height: 10).accessibilityHidden(true)
                            }
                        }.accessibilityElement(children: .combine)
                    }
                    Text("Correct by round").font(.headline).padding(.top, 4)
                    ForEach(0..<5) { index in
                        ViewThatFits(in: .horizontal) {
                            HStack { Text(session.puzzle.rounds[index].shortName); Spacer(); Text(summary.rateLabel(index)) }
                            VStack(alignment: .leading) { Text(session.puzzle.rounds[index].shortName); Text(summary.rateLabel(index)) }
                        }.font(.subheadline).accessibilityElement(children: .combine)
                    }
                    Text("Opted-in results only. Counts and rates are grouped for privacy; small score groups are hidden. Self-reported scores, not a verified ranking.")
                        .font(.caption).foregroundStyle(ColorTheme.textSecondary)
                } else {
                    Text("Community stats are unavailable for this set.")
                }
            }
        }.fixedSize(horizontal: false, vertical: true)
            .padding(20).background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 22))
    }

    private var sampleLabel: some View {
        Text("SAMPLE LAYOUT · FICTIONAL DATA")
            .font(.caption.bold()).foregroundStyle(ColorTheme.barre)
            .accessibilityIdentifier("riff.community.sample")
    }
}
