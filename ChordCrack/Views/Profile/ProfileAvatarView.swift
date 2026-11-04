import SwiftUI

struct ProfileAvatarBadge: View {
    let avatar: ProfileAvatar
    let username: String
    var size: CGFloat = 44
    private var accent: Color {
        switch avatar {
        case .initial, .guitar, .wave: return ColorTheme.primaryGreen
        case .keys, .star, .bolt: return ColorTheme.warning
        case .headphones, .note, .sparkle: return ColorTheme.progression
        }
    }
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [accent, accent.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1)
            if let symbol = avatar.symbol { Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold)) }
            else if ProfileAvatar.initial(for: username).isEmpty { Image(systemName: "person.fill").font(.system(size: size * 0.42)) }
            else { Text(ProfileAvatar.initial(for: username)).font(.system(size: size * 0.42, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1).padding(size * 0.15) }
        }
        .foregroundStyle(ColorTheme.background).frame(width: size, height: size)
        .accessibilityElement(children: .ignore).accessibilityLabel("\(avatar.title) avatar")
    }
}

struct ProfileAvatarPicker: View {
    @ObservedObject var store: ProfileAvatarStore
    let username: String
    @State private var selected: ProfileAvatar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var textSize

    init(store: ProfileAvatarStore, username: String) {
        self.store = store; self.username = username
        _selected = State(initialValue: store.avatar)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ProfileAvatarBadge(avatar: selected, username: username, size: 88)
                        .shadow(color: ColorTheme.primaryGreen.opacity(0.15), radius: 14, y: 6)
                    if !textSize.isAccessibilitySize {
                        Text(username).font(.title2.bold()).foregroundStyle(ColorTheme.textPrimary)
                        Text("Choose a music icon or keep your initial.")
                            .font(.subheadline).foregroundStyle(ColorTheme.textSecondary).multilineTextAlignment(.center)
                    }
                    LazyVGrid(columns: textSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 88), spacing: 12)], spacing: 12) {
                        ForEach(ProfileAvatar.allCases) { choice in
                            Button { selected = choice } label: {
                                VStack(spacing: 10) {
                                    ProfileAvatarBadge(avatar: choice, username: username, size: 52)
                                        .accessibilityHidden(true)
                                    Text(choice.title).font(.caption.weight(.semibold))
                                        .foregroundStyle(ColorTheme.textPrimary).multilineTextAlignment(.center)
                                }.frame(maxWidth: .infinity, minHeight: 100).padding(8)
                                    .background(ColorTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(selected == choice ? ColorTheme.primaryGreen : .clear, lineWidth: 3))
                                    .overlay(alignment: .topTrailing) {
                                        if selected == choice {
                                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(ColorTheme.primaryGreen).padding(5).accessibilityHidden(true)
                                        }
                                    }
                            }
                            .buttonStyle(.plain).disabled(store.isSaving)
                            .accessibilityLabel(choice.title)
                            .accessibilityValue(selected == choice ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selected == choice ? .isSelected : [])
                            .accessibilityIdentifier("avatar.option.\(choice.rawValue)")
                        }
                    }
                    if store.isSaving { ProgressView("Saving avatar…").accessibilityIdentifier("avatar.saving") }
                    if let error = store.errorMessage {
                        Text(error).foregroundStyle(ColorTheme.warning).accessibilityIdentifier("avatar.error")
                    }
                    Text(store.isPreview ? "Preview only · Choices stay in this session." : "Your avatar follows your statistics-sharing and leaderboard visibility settings. No photos are collected.")
                        .font(.footnote).foregroundStyle(ColorTheme.textSecondary).multilineTextAlignment(.center)
                }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(ColorTheme.background.ignoresSafeArea())
            .navigationTitle("Choose an avatar").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.clearError(); dismiss() }.disabled(store.isSaving).accessibilityIdentifier("avatar.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { if await store.save(selected) { dismiss() } } }
                        .disabled(store.isSaving || store.isLoading || !store.canEdit || selected == store.avatar)
                        .accessibilityIdentifier("avatar.save")
                }
            }
            .interactiveDismissDisabled(store.isSaving)
            .onAppear { store.clearError() }
        }.tint(ColorTheme.primaryGreen).preferredColorScheme(.dark)
    }
}
