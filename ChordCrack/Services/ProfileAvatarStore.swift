import Foundation
import Combine

/// Own avatar only; memory is invalidated synchronously on every identity change.
/// Social avatars are fetched separately under RLS and are never persisted here.
@MainActor final class ProfileAvatarStore: ObservableObject {
    static let shared = ProfileAvatarStore()
    @Published private(set) var avatar: ProfileAvatar = .initial
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    let isPreview: Bool
    var canEdit: Bool { isPreview || accountID != nil }
    private let service: any AvatarServicing
    private var accountID: String?
    private var revision = UUID()
    private var observation: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    init(service: any AvatarServicing = AvatarAPIService(), preview: Bool = DesignDemo.isEnabled,
         observeAuthentication: Bool = true) {
        self.service = service; isPreview = preview
        guard !preview, observeAuthentication else { return }
        let supabase = SupabaseClient.shared
        observation = supabase.$isAuthenticated.combineLatest(supabase.$user.map { $0?.id.lowercased() })
            .map { authenticated, id in authenticated ? id : nil }.removeDuplicates()
            .sink { [weak self] id in self?.setAccount(id) }
    }
    deinit { refreshTask?.cancel() }

    func setAccount(_ id: String?) {
        guard !isPreview, accountID != id else { return }
        accountID = id
        revision = UUID()
        refreshTask?.cancel()
        avatar = .initial; errorMessage = nil; isLoading = false; isSaving = false
        if id != nil { refreshTask = Task { [weak self] in await self?.refresh() } }
    }
    func refresh() async {
        guard !isPreview, !isLoading, !isSaving, !Task.isCancelled, let owner = accountID else { return }
        let token = UUID(); revision = token
        isLoading = true; errorMessage = nil
        defer { if revision == token, accountID == owner { isLoading = false } }
        do {
            let result = try await service.load(userIDs: [owner])
            guard revision == token, accountID == owner, !Task.isCancelled else { return }
            avatar = result[owner.lowercased()] ?? .initial
        } catch {
            guard revision == token, accountID == owner, !Task.isCancelled else { return }
            avatar = .initial
            errorMessage = "Your avatar couldn’t load. You can try again."
        }
    }
    @discardableResult func save(_ choice: ProfileAvatar) async -> Bool {
        guard canEdit, !isLoading, !isSaving, !Task.isCancelled else { return false }
        errorMessage = nil
        if isPreview { avatar = choice; return true } // Memory only; never writes preview data.
        guard let owner = accountID else { return false }
        let token = UUID(); revision = token
        isSaving = true
        defer { if revision == token, accountID == owner { isSaving = false } }
        do {
            let saved = try await service.save(choice, for: owner)
            guard revision == token, accountID == owner, !Task.isCancelled else { return false }
            avatar = saved
            return true
        } catch {
            guard revision == token, accountID == owner, !Task.isCancelled else { return false }
            errorMessage = "We couldn’t confirm your change. Please try saving again."
            return false
        }
    }
    func clearError() { errorMessage = nil }
}
