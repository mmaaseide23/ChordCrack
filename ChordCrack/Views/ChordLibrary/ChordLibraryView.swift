import SwiftUI

struct ChordLibraryView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var selectedCategory: ChordCategory? = nil
    @State private var searchText = ""

    private var filteredChords: [ChordType] {
        let chords: [ChordType]
        if let category = selectedCategory {
            switch category {
            case .basic: chords = ChordType.basicChords
            case .barre: chords = ChordType.barreChords
            case .blues: chords = ChordType.bluesChords
            case .power: chords = ChordType.powerChords
            }
        } else {
            chords = ChordType.allCases.map { $0 }
        }

        if searchText.isEmpty {
            return chords
        }
        return chords.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedChords: [(ChordCategory, [ChordType])] {
        if let category = selectedCategory {
            return [(category, filteredChords)]
        }
        return ChordCategory.allCases.compactMap { category in
            let chords = filteredChords.filter { $0.category == category }
            return chords.isEmpty ? nil : (category, chords)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Search bar
                searchBar

                // Category filter chips
                categoryFilterRow

                // Chord count
                HStack {
                    Text("\(filteredChords.count) chords")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ColorTheme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Chord grid by category
                ForEach(groupedChords, id: \.0) { category, chords in
                    categorySection(category: category, chords: chords)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(ColorTheme.background)
        .navigationTitle("Chord Library")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ColorTheme.textSecondary)
                .font(.system(size: 15))

            TextField("Search chords...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ColorTheme.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ColorTheme.textTertiary)
                        .font(.system(size: 15))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ColorTheme.textTertiary.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Category Filter

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryChip(title: "All", category: nil, icon: "music.note.list")

                ForEach(ChordCategory.allCases, id: \.rawValue) { category in
                    categoryChip(title: category.rawValue, category: category, icon: category.icon)
                }
            }
        }
    }

    private func categoryChip(title: String, category: ChordCategory?, icon: String) -> some View {
        let isSelected = selectedCategory == category
        let chipColor = category?.color ?? ColorTheme.primaryGreen

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : chipColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? chipColor : chipColor.opacity(0.15))
            )
        }
    }

    // MARK: - Category Section

    private func categorySection(category: ChordCategory, chords: [ChordType]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 10) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(category.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(ColorTheme.textPrimary)

                    Text(category.description)
                        .font(.system(size: 12))
                        .foregroundColor(ColorTheme.textSecondary)
                }

                Spacer()

                Text("\(chords.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(category.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(category.color.opacity(0.15))
                    )
            }

            // Chord cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(chords) { chord in
                    NavigationLink(destination: ChordDetailView(chord: chord)
                        .environmentObject(audioManager)) {
                        chordCard(chord: chord, category: category)
                    }
                    .buttonStyle(PlainButtonStyle())
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
        HStack(spacing: 10) {
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ColorTheme.textPrimary)
                    .lineLimit(1)

                Text("\(chord.fingerPositions.count) strings")
                    .font(.system(size: 11))
                    .foregroundColor(ColorTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(ColorTheme.textTertiary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorTheme.secondaryBackground)
        )
    }
}

#Preview {
    NavigationStack {
        ChordLibraryView()
            .environmentObject(AudioManager())
    }
    .preferredColorScheme(.dark)
}
