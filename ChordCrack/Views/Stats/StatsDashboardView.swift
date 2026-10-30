import SwiftUI
import Charts

/// Comprehensive stats dashboard showing accuracy trends, category breakdowns,
/// weakest chords, and recent session history.
struct StatsDashboardView: View {
    @EnvironmentObject var userDataManager: UserDataManager
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedRange: TimeRange = .last30

    enum TimeRange: String, CaseIterable, Identifiable {
        case last7 = "7D"
        case last30 = "30D"
        case allTime = "All"

        var id: String { rawValue }

        var dayLimit: Int? {
            switch self {
            case .last7: return 7
            case .last30: return 30
            case .allTime: return nil
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                summaryCard
                accuracyTrendCard
                categoryBreakdownCard
                weakestChordsCard
                strongestChordsCard
                recentSessionsCard
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Stats Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .background(ColorTheme.background.ignoresSafeArea())
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(icon: "gamecontroller.fill",
                        color: .blue,
                        value: "\(userDataManager.totalGamesPlayed)",
                        label: "Games")
            Divider().frame(height: 36).background(ColorTheme.textTertiary.opacity(0.2))
            summaryItem(icon: "target",
                        color: ColorTheme.primaryGreen,
                        value: String(format: "%.0f%%", userDataManager.overallAccuracy),
                        label: "Accuracy")
            Divider().frame(height: 36).background(ColorTheme.textTertiary.opacity(0.2))
            summaryItem(icon: "flame.fill",
                        color: .orange,
                        value: "\(userDataManager.bestStreak)",
                        label: "Best Streak")
            Divider().frame(height: 36).background(ColorTheme.textTertiary.opacity(0.2))
            summaryItem(icon: "star.fill",
                        color: .yellow,
                        value: "\(userDataManager.bestScore)",
                        label: "Best Score")
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
        )
    }

    private func summaryItem(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(ColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Accuracy Trend

    private var accuracyTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Accuracy Over Time")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)

                Spacer()

                Picker("Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            let points = trendPoints()

            if points.isEmpty {
                emptyState(message: "Play more games to see trends")
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Accuracy", point.accuracy)
                    )
                    .foregroundStyle(ColorTheme.primaryGreen)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Accuracy", point.accuracy)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorTheme.primaryGreen.opacity(0.35), ColorTheme.primaryGreen.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Accuracy", point.accuracy)
                    )
                    .foregroundStyle(ColorTheme.primaryGreen)
                    .symbolSize(30)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 180)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
        )
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accuracy by Category")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)

            let entries = categoryEntries()

            if entries.allSatisfy({ $0.accuracy == 0 }) {
                emptyState(message: "Play some practice modes to see your category breakdown")
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Accuracy", entry.accuracy),
                        y: .value("Category", entry.label)
                    )
                    .foregroundStyle(entry.color)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(String(format: "%.0f%%", entry.accuracy))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(ColorTheme.textSecondary)
                    }
                }
                .chartXScale(domain: 0...100)
                .frame(height: CGFloat(entries.count) * 34 + 20)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
        )
    }

    // MARK: - Weakest Chords

    private var weakestChordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
                Text("Focus Areas")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
            }

            let weak = userDataManager.weakestChords(limit: 5, minAttempts: 3)

            if weak.isEmpty {
                emptyState(message: "Play at least 3 rounds with a chord to see focus areas")
            } else {
                VStack(spacing: 6) {
                    ForEach(weak, id: \.0) { (chord, data) in
                        chordAccuracyRow(chord: chord, data: data, tintColor: .orange)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
        )
    }

    // MARK: - Strongest Chords

    private var strongestChordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
                Text("Your Best Chords")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ColorTheme.textPrimary)
            }

            let strong = userDataManager.strongestChords(limit: 5, minAttempts: 3)

            if strong.isEmpty {
                emptyState(message: "Keep practicing to build your strongest chords list")
            } else {
                VStack(spacing: 6) {
                    ForEach(strong, id: \.0) { (chord, data) in
                        chordAccuracyRow(chord: chord, data: data, tintColor: ColorTheme.primaryGreen)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
        )
    }

    private func chordAccuracyRow(chord: ChordType, data: ChordAccuracyData, tintColor: Color) -> some View {
        HStack(spacing: 10) {
            Text(chord.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ColorTheme.textPrimary)
                .frame(width: 56, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColorTheme.secondaryBackground)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(tintColor)
                        .frame(width: max(4, geo.size.width * CGFloat(data.accuracy / 100.0)), height: 8)
                }
            }
            .frame(height: 8)

            Text(String(format: "%.0f%%", data.accuracy))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tintColor)
                .frame(width: 40, alignment: .trailing)

            Text("(\(data.correct)/\(data.total))")
                .font(.system(size: 10))
                .foregroundColor(ColorTheme.textTertiary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ColorTheme.textPrimary)

            let sessions = Array(userDataManager.gameHistory.sorted { $0.createdAt > $1.createdAt }.prefix(8))

            if sessions.isEmpty {
                emptyState(message: "Complete a game to see your session history")
            } else {
                VStack(spacing: 6) {
                    ForEach(sessions, id: \.id) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ColorTheme.cardBackground)
        )
    }

    private func sessionRow(_ session: GameSession) -> some View {
        let accuracy: Double = session.totalQuestions > 0
            ? Double(session.correctAnswers) / Double(session.totalQuestions) * 100
            : 0

        return HStack(spacing: 10) {
            Circle()
                .fill(sessionColor(session.gameType))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(for: session.gameType))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)

                Text(StatsDateFormatter.shortFormat.string(from: session.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(ColorTheme.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.score) pts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ColorTheme.primaryGreen)

                Text(String(format: "%.0f%% accuracy", accuracy))
                    .font(.system(size: 10))
                    .foregroundColor(ColorTheme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ColorTheme.secondaryBackground.opacity(0.4))
        )
    }

    // MARK: - Empty State

    private func emptyState(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 22))
                    .foregroundColor(ColorTheme.textTertiary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(ColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Data Builders

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let accuracy: Double
    }

    private func trendPoints() -> [TrendPoint] {
        let calendar = Calendar.current
        let now = Date()

        var sessions = userDataManager.gameHistory

        if let days = selectedRange.dayLimit,
           let cutoff = calendar.date(byAdding: .day, value: -days, to: now) {
            sessions = sessions.filter { $0.createdAt >= cutoff }
        }

        guard !sessions.isEmpty else { return [] }

        // Group by day
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            calendar.startOfDay(for: session.createdAt)
        }

        let points: [TrendPoint] = grouped.map { (date, sessionsForDay) in
            let totalCorrect = sessionsForDay.reduce(0) { $0 + $1.correctAnswers }
            let totalQuestions = sessionsForDay.reduce(0) { $0 + $1.totalQuestions }
            let accuracy = totalQuestions > 0
                ? Double(totalCorrect) / Double(totalQuestions) * 100
                : 0
            return TrendPoint(date: date, accuracy: accuracy)
        }

        return points.sorted { $0.date < $1.date }
    }

    private struct CategoryEntry: Identifiable {
        let id = UUID()
        let label: String
        let accuracy: Double
        let color: Color
    }

    private func categoryEntries() -> [CategoryEntry] {
        [
            CategoryEntry(label: "Daily", accuracy: userDataManager.categoryAccuracy(for: GameTypeConstants.dailyChallenge), color: ColorTheme.primaryGreen),
            CategoryEntry(label: "Power", accuracy: userDataManager.categoryAccuracy(for: GameTypeConstants.powerChords), color: .red),
            CategoryEntry(label: "Barre", accuracy: userDataManager.categoryAccuracy(for: GameTypeConstants.barreChords), color: .orange),
            CategoryEntry(label: "Blues", accuracy: userDataManager.categoryAccuracy(for: GameTypeConstants.bluesChords), color: .blue),
            CategoryEntry(label: "Extended", accuracy: userDataManager.categoryAccuracy(for: GameTypeConstants.extendedChords), color: .teal),
            CategoryEntry(label: "Mixed", accuracy: userDataManager.categoryAccuracy(for: GameTypeConstants.mixedPractice), color: .purple),
            CategoryEntry(label: "Progress.", accuracy: userDataManager.categoryAccuracy(for: GameTypeConstants.chordProgressions), color: .indigo)
        ]
    }

    private func sessionColor(_ gameType: String) -> Color {
        switch gameType {
        case GameTypeConstants.dailyChallenge: return ColorTheme.primaryGreen
        case GameTypeConstants.powerChords: return .red
        case GameTypeConstants.barreChords: return .orange
        case GameTypeConstants.bluesChords: return .blue
        case GameTypeConstants.extendedChords: return .teal
        case GameTypeConstants.mixedPractice: return .purple
        case GameTypeConstants.chordProgressions: return .indigo
        case GameTypeConstants.basicChords: return ColorTheme.primaryGreen
        default: return ColorTheme.textTertiary
        }
    }

    private func displayName(for gameType: String) -> String {
        switch gameType {
        case GameTypeConstants.dailyChallenge: return "Daily Challenge"
        case GameTypeConstants.powerChords: return "Power Chords"
        case GameTypeConstants.barreChords: return "Barre Chords"
        case GameTypeConstants.bluesChords: return "Blues Chords"
        case GameTypeConstants.extendedChords: return "Extended Chords"
        case GameTypeConstants.mixedPractice: return "Mixed Practice"
        case GameTypeConstants.chordProgressions: return "Progressions"
        case GameTypeConstants.basicChords: return "Basic Chords"
        case GameTypeConstants.speedRound: return "Speed Round"
        default: return gameType.capitalized
        }
    }
}

// MARK: - Date Formatter

private enum StatsDateFormatter {
    static let shortFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()
}
