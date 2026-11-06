import Foundation
import Combine

@MainActor
final class CloudSyncController: ObservableObject {
    static let shared = CloudSyncController()
    @Published private(set) var enabled: Bool
    @Published private(set) var committeeSyncEnabled: Bool
    @Published private(set) var dossiers: [CloudDossier] = []
    @Published private(set) var committeeVersions: [CloudCommitteeVersion] = []
    @Published private(set) var busy = false
    @Published private(set) var isReady = false
    @Published private(set) var error: String?
    @Published private(set) var status = ""
    @Published private(set) var activationID = UUID()
    private var store: CloudSyncStore?
    private let defaults: UserDefaults
    private let storeFactory: @MainActor () throws -> CloudSyncStore
    private let autosaveDelay: Duration
    private let committeeLibrary: CommitteeLibrary
    private var generation = UUID()
    private var refreshTask: Task<Void, Never>?
    private var autosaveTasks: [UUID: Task<Void, Never>] = [:]
    private var lastUploadedRevision: [UUID: UUID] = [:]
    private var committeeSubscription: AnyCancellable?
    private var activeWindows: Set<UUID> = []

    init(defaults: UserDefaults = .standard, committeeLibrary: CommitteeLibrary? = nil,
         autosaveDelay: Duration = .seconds(2),
         storeFactory: @escaping @MainActor () throws -> CloudSyncStore = CloudSyncController.defaultStore) {
        self.defaults = defaults
        self.storeFactory = storeFactory
        self.autosaveDelay = autosaveDelay
        self.committeeLibrary = committeeLibrary ?? .shared
        enabled = defaults.bool(forKey: "personalCloudSyncEnabled")
        committeeSyncEnabled = defaults.bool(forKey: "committeeCloudSyncEnabled")
        committeeSubscription = self.committeeLibrary.$committees.dropFirst().sink { [weak self] committees in
            Task { @MainActor in await self?.uploadCommittees(committees) }
        }
    }
    func activateIfNeeded(allowAccountChange: Bool = false) async {
        guard enabled, !isReady, !busy else { return }
        let expected = generation
        busy = true
        defer { if generation == expected { busy = false } }
        let candidate: CloudSyncStore
        do { candidate = try makeStore() }
        catch { self.error = cloudErrorDescription(error); return }
        do {
            let items = try await candidate.activate(allowAccountChange: allowAccountChange)
            guard generation == expected, enabled else { await candidate.deactivate(); return }
            store = candidate; dossiers = items; isReady = true
            error = nil; status = "iCloud-bibliotheek bijgewerkt."
            if committeeSyncEnabled { try await candidate.saveCommittees(committeeLibrary.committees) }
            guard generation == expected, enabled else { return }
            await refreshCommitteeVersions()
            if !activeWindows.isEmpty { startRefreshLoop() }
            Task { await self.refresh() }
        } catch {
            guard generation == expected else { await candidate.deactivate(); return }
            if case CloudSyncError.accountChanged = error { stopForAccountChange(); return }
            // Account identity couldn't be established. Keep cached files readable
            // and may queue edits only into that cached account’s namespace.
            // Sending still requires successful account verification.
            store = candidate; isReady = false
            dossiers = (try? await candidate.dossiers()) ?? []
            guard generation == expected else { return }
            self.error = cloudErrorDescription(error); status = "iCloud is niet beschikbaar. Lokale kopieën blijven leesbaar."
            if !activeWindows.isEmpty, refreshTask == nil { startRefreshLoop() }
        }
    }
    static func defaultStore() throws -> CloudSyncStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CommissieWijzer/iCloud", isDirectory: true)
            .appendingPathComponent(Bundle.main.object(forInfoDictionaryKey: "CWCloudKitEnvironment") as? String ?? "Disabled", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return CloudSyncStore(directory: base, transport: CloudKitSyncTransport())
    }
    private func makeStore() throws -> CloudSyncStore { try storeFactory() }

    func setEnabled(_ value: Bool) async {
        guard enabled != value else { return }
        enabled = value; defaults.set(value, forKey: "personalCloudSyncEnabled")
        activationID = UUID()
        generation = UUID(); let expected = generation
        refreshTask?.cancel(); refreshTask = nil
        autosaveTasks.values.forEach { $0.cancel() }; autosaveTasks.removeAll()
        busy = false; isReady = false
        let previous = store
        if let previous { await previous.deactivate() }
        guard generation == expected else { return }
        if !value { status = "Synchronisatie staat uit. Lokale kopieën blijven beschikbaar."; return }
        // An explicit activation starts a fresh sharing choice. In particular,
        // a former account's committee opt-in must not carry over to a new one.
        committeeSyncEnabled = false; defaults.set(false, forKey: "committeeCloudSyncEnabled")
        await activateIfNeeded(allowAccountChange: true)
    }

    func setCommitteeSyncEnabled(_ value: Bool) async {
        guard enabled, committeeSyncEnabled != value else { return }
        committeeSyncEnabled = value; defaults.set(value, forKey: "committeeCloudSyncEnabled")
        guard let store else { return }
        if value {
            do { try await store.saveCommittees(committeeLibrary.committees); await synchronize() }
            catch { self.error = error.localizedDescription }
        } else { committeeVersions = [] }
    }

    func refresh() async {
        guard enabled, !busy else { return }
        if !isReady { await activateIfNeeded(); return }
        guard let store else { return }
        busy = true; let expected = generation
        defer { if generation == expected { busy = false } }
        do {
            let updated = try await store.synchronize(includeCommittees: committeeSyncEnabled)
            guard generation == expected, enabled else { return }
            dossiers = updated; error = nil; status = "Synchronisatie bijgewerkt."; await refreshCommitteeVersions()
        } catch {
            guard generation == expected else { return }
            if case CloudSyncError.accountChanged = error { stopForAccountChange(); return }
            self.error = cloudErrorDescription(error); status = "Synchronisatie wacht op verbinding."
        }
    }

    func synchronize() async { await refresh() }
    @discardableResult func upload(_ archive: WorkspaceArchive, dossierID: UUID?, baseRevision: String? = nil) async -> CloudDossier? {
        guard enabled, let store else { return nil }
        let expected = generation
        let offline = !isReady
        do {
            let item = try await store.save(archive, dossierID: dossierID, baseRevision: baseRevision, allowOfflineCache: offline)
            guard generation == expected else { return nil }
            if let index = dossiers.firstIndex(where: { $0.id == item.id }) { dossiers[index] = item }
            else { dossiers.insert(item, at: 0) }
            status = "Wijzigingen lokaal in de synchronisatiewachtrij bewaard."; error = nil
            if !offline { Task { await self.refresh() } }
            return item
        } catch {
            if generation == expected {
                if case CloudSyncError.accountChanged = error { stopForAccountChange() }
                else { self.error = cloudErrorDescription(error) }
            }
            return nil
        }
    }
    func checkout(id: UUID) async throws -> CloudCheckout {
        guard let store else { throw CloudSyncError.notActivated }
        let expected = generation
        let checkout = try await store.checkout(dossierID: id)
        guard generation == expected else { throw CloudSyncError.accountChanged }
        return checkout
    }
    func markWorkspaceUploaded(_ workspaceID: UUID, revision: UUID) { lastUploadedRevision[workspaceID] = revision }
    func loadLocalLibrary() async {
        if enabled { await activateIfNeeded() }
        guard !isReady else { return }
        let expected = generation
        do {
            let local = try store ?? makeStore()
            let items = try await local.dossiers()
            guard generation == expected else { return }
            store = local; dossiers = items
            if committeeSyncEnabled { committeeVersions = try await local.committeeVersions() }
            if !enabled { status = "Lokale kopieën zijn beschikbaar." }
        } catch { if generation == expected { self.error = cloudErrorDescription(error) } }
    }
    func refreshCommitteeVersions() async {
        guard enabled, committeeSyncEnabled, let store else { committeeVersions = []; return }
        let expected = generation
        do {
            let versions = try await store.committeeVersions()
            guard generation == expected, enabled, committeeSyncEnabled else { return }
            committeeVersions = versions
        } catch { if generation == expected { self.error = cloudErrorDescription(error) } }
    }
    func uploadCommittees(_ committees: [MeetingPurpose]) async {
        guard enabled, isReady, committeeSyncEnabled, let store else { return }
        let expected = generation
        do {
            try await store.saveCommittees(committees)
            guard generation == expected, committeeSyncEnabled else { return }
            await refreshCommitteeVersions()
            await refresh()
        } catch { if generation == expected { self.error = cloudErrorDescription(error) } }
    }
    func applyCommitteeVersion(_ version: CloudCommitteeVersion) throws {
        for purpose in version.committees where purpose != .raad {
            if let definition = purpose.committee { try committeeLibrary.save(definition) }
        }
    }
    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                guard !Task.isCancelled, let self, self.enabled else { return }
                guard !self.activeWindows.isEmpty else { continue }
                await self.refresh()
            }
        }
    }
    func scheduleUpload(workspaceID: UUID, archive: @escaping @MainActor () -> WorkspaceArchive?, binding: @escaping @MainActor () -> (UUID, String?)?, revision: UUID, completion: @escaping @MainActor (CloudDossier) -> Void) {
        guard enabled else { return }
        let previous = autosaveTasks[workspaceID]
        autosaveTasks[workspaceID]?.cancel()
        autosaveTasks[workspaceID] = Task { [weak self] in
            if let previous { await previous.value }
            guard let self else { return }
            try? await Task.sleep(for: self.autosaveDelay)
            guard !Task.isCancelled, self.enabled, self.lastUploadedRevision[workspaceID] != revision,
                  let (dossierID, baseRevision) = binding(), let snapshot = archive() else { return }
            if let item = await self.upload(snapshot, dossierID: dossierID, baseRevision: baseRevision) {
                self.lastUploadedRevision[workspaceID] = revision
                completion(item)
            }
        }
    }

    func setWindowActive(_ id: UUID, _ isActive: Bool) {
        if isActive { activeWindows.insert(id) } else { activeWindows.remove(id) }
        if activeWindows.isEmpty { refreshTask?.cancel(); refreshTask = nil }
        else if enabled, refreshTask == nil { startRefreshLoop() }
    }

    private func stopForAccountChange() {
        enabled = false; defaults.set(false, forKey: "personalCloudSyncEnabled")
        committeeSyncEnabled = false; defaults.set(false, forKey: "committeeCloudSyncEnabled")
        activationID = UUID(); generation = UUID()
        refreshTask?.cancel(); refreshTask = nil
        autosaveTasks.values.forEach { $0.cancel() }; autosaveTasks.removeAll()
        let previous = store
        Task { await previous?.deactivate() }
        store = nil; dossiers = []; committeeVersions = []; busy = false; isReady = false
        status = "iCloud-account gewijzigd. Schakel synchronisatie opnieuw in om per dossier te kiezen wat je deelt."
    }

    private func cloudErrorDescription(_ error: Error) -> String {
        if case CloudSyncError.previewBuild = error { return "Deze lokale testversie heeft geen iCloud-toegang. Open de voor iCloud ondertekende versie van CommissieWijzer." }
        if case CloudSyncError.unavailable = error { return "Deze installatie heeft geen geldige iCloud-bevoegdheid. Open een versie met een passend iCloud-profiel." }
        if case CloudSyncError.missingAccount = error { return "Meld je op dit apparaat aan bij iCloud om synchronisatie te gebruiken." }
        return error.localizedDescription
    }
}
