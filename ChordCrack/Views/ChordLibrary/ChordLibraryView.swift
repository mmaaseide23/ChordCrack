import SwiftUI

struct ChordLibraryView: View {
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedCategory: ChordCategory? = nil
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filteredChords: [ChordType] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return ChordType.allCases.filter { chord in
            (selectedCategory == nil || chord.category == selectedCategory) &&
            (query.isEmpty || chord.displayName.localizedCaseInsensitiveContains(query))
        }
    }

    private var groupedChords: [(ChordCategory, [ChordType])] {
        ChordCategory.allCases.compactMap { category in
            let chords = filteredChords.filter { $0.category == category }
            return chords.isEmpty ? nil : (category, chords)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(spacing: 14) {
                    searchBar
                    categoryFilterRow
                }
                if filteredChords.isEmpty {
                    emptyResults
                } else {
                    Text("\(filteredChords.count) chords")
                        .font(.caption).foregroundStyle(ColorTheme.textSecondary)
                    ForEach(groupedChords, id: \.0) { category, chords in
                        categorySection(category: category, chords: chords)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 40)
            .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ColorTheme.background.ignoresSafeArea())
        .navigationTitle("Chord Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(ColorTheme.primaryGreen)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(ColorTheme.textSecondary).accessibilityHidden(true)
            TextField("Search chords", text: $searchText, prompt: Text("Search chords").foregroundColor(ColorTheme.textSecondary))
                .font(.body).foregroundStyle(ColorTheme.textPrimary)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .focused($searchFocused).submitLabel(.search)
                .onSubmit { searchFocused = false }
                .accessibilityIdentifier("library.search")
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorTheme.textSecondary).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("library.clear")
            }
        }
        .padding(.leading, 16).padding(.trailing, searchText.isEmpty ? 16 : 4)
        .frame(minHeight: 56)
        .background(ColorTheme.secondaryBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "All", category: nil)
                ForEach(ChordCategory.allCases, id: \.rawValue) { category in
                    categoryChip(title: category.rawValue, category: category)
                }
            }
        }
    }

    private func categoryChip(title: String, category: ChordCategory?) -> some View {
        let isSelected = selectedCategory == category
        let color = category?.color ?? ColorTheme.primaryGreen
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { selectedCategory = category }
        } label: {
            Label(title, systemImage: category?.icon ?? "music.note.list").font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? ColorTheme.background : color)
                .padding(.horizontal, 18).frame(minHeight: 44)
                .background(isSelected ? color : color.opacity(0.12),
                            in: Capsule())
        }
        .buttonStyle(StudioPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("library.filter.\(title)")
    }

    private var emptyResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(ColorTheme.primaryGreen)
            Text("No matching chords").font(.title2.weight(.bold)).foregroundStyle(ColorTheme.textPrimary)
            Text("Try a name like A Major, or explore all categories.")
                .font(.body).foregroundStyle(ColorTheme.textSecondary)
            Button("Show all chords") {
                searchText = ""
                selectedCategory = nil
                searchFocused = false
            }
            .font(.headline).foregroundStyle(ColorTheme.background)
            .padding(.horizontal, 20).frame(minHeight: 48)
            .background(ColorTheme.primaryGreen, in: RoundedRectangle(cornerRadius: 12))
            .buttonStyle(StudioPressStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 28)
    }

    private func categorySection(category: ChordCategory, chords: [ChordType]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(category.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(ColorTheme.textPrimary)

                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(ColorTheme.textSecondary)
                }

                Spacer()

                Text("\(chords.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(category.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(category.color.opacity(0.15))
                    )
            }

            // Chord cards grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 260 : 130), spacing: 10)], spacing: 10) {
                ForEach(chords) { chord in
                    NavigationLink(destination: ChordDetailView(chord: chord)
                        .environmentObject(audioManager)) {
                        chordCard(chord: chord, category: category)
                    }
                    .buttonStyle(StudioPressStyle())
                    .accessibilityIdentifier("library.chord.\(chord.rawValue)")
                    .accessibilityLabel("\(chord.displayName), view fingering and listen")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(category.color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Chord Card

    private func chordCard(chord: ChordType, category: ChordCategory) -> some View {
        HStack(spacing: 8) {
            // Mini guitar neck icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "guitars.fill")
                    .font(.system(size: 16))
                    .foregroundColor(category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(chord.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(chord.fingerPositions.count) strings")
                    .font(.caption2)
                    .foregroundColor(ColorTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(ColorTheme.textTertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTheme.secondaryBackground)
        )
    }
}
