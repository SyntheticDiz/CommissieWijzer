import XCTest
@testable import CommissieWijzer

private actor ControllerLifecycleTransport: CloudSyncTransport {
    private var account = "account-A"
    private var offline = false
    private var calls = 0
    private var nextRevision = 0
    private var dossiers: [UUID: (CloudRemoteDossier, Data)] = [:]
    private var suspendNextIdentifier = false
    private var suspendedIdentifier: CheckedContinuation<String, Error>?
    private var suspensionWaiter: CheckedContinuation<Void, Never>?

    func setAccount(_ value: String) { account = value }
    func setOffline(_ value: Bool) { offline = value }
    func callCount() -> Int { calls }

    func suspendNextAccountIdentifier() { suspendNextIdentifier = true }
    func waitForSuspendedAccountIdentifier() async {
        if suspendedIdentifier != nil { return }
        await withCheckedContinuation { suspensionWaiter = $0 }
    }
    func releaseAccountIdentifier() {
        guard let continuation = suspendedIdentifier else { return }
        suspendedIdentifier = nil
        continuation.resume(returning: account)
    }

    func accountIdentifier() async throws -> String {
        calls += 1
        if suspendNextIdentifier {
            suspendNextIdentifier = false
            return try await withCheckedThrowingContinuation { continuation in
                suspendedIdentifier = continuation
                suspensionWaiter?.resume()
                suspensionWaiter = nil
            }
        }
        if offline { throw CloudSyncError.unavailable }
        return account
    }
    func activateAccount(_ accountIdentifier: String) async throws { calls += 1 }
    func listDossiers() async throws -> [CloudRemoteDossier] { calls += 1; return dossiers.values.map(\.0) }
    func fetchArchive(id: UUID) async throws -> CloudArchiveDownload {
        calls += 1
        guard let value = dossiers[id] else { throw CloudSyncError.dossierMissing }
        return CloudArchiveDownload(archive: value.1, metadata: value.0)
    }
    func saveArchive(id: UUID, title: String, modifiedAt: Date, contentHash: String,
                     expectedRevision: String?, archive: Data) async throws -> CloudRemoteDossier {
        calls += 1
        if let existing = dossiers[id], existing.0.revision != expectedRevision { throw CloudSyncError.conflict }
        if dossiers[id] == nil, expectedRevision != nil { throw CloudSyncError.conflict }
        nextRevision += 1
        let remote = CloudRemoteDossier(id: id, title: title, modifiedAt: modifiedAt,
                                        revision: "controller-\(nextRevision)", contentHash: contentHash)
        dossiers[id] = (remote, archive)
        return remote
    }
    func listCommitteeVersions() async throws -> [CloudRemoteCommitteeVersion] { calls += 1; return [] }
    func fetchCommittees(id: UUID) async throws -> CloudCommitteeDownload {
        calls += 1; throw CloudSyncError.dossierMissing
    }
    func saveCommittees(id: UUID, modifiedAt: Date, contentHash: String,
                        expectedRevision: String?, payload: Data) async throws -> CloudRemoteCommitteeVersion {
        calls += 1; throw CloudSyncError.unavailable
    }
}

@MainActor
private final class PendingWindowSave {
    var dossierID: UUID
    var baseRevision: String?
    var archive: WorkspaceArchive
    init(dossierID: UUID, baseRevision: String?, archive: WorkspaceArchive) {
        self.dossierID = dossierID
        self.baseRevision = baseRevision
        self.archive = archive
    }
}

@MainActor
final class CloudSyncControllerLifecycleTests: XCTestCase {
    func testPersistedEnabledPreferenceActivatesOnStartup() async throws {
        let (suite, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "personalCloudSyncEnabled")
        let transport = ControllerLifecycleTransport()
        let controller = makeController(defaults: defaults, transport: transport, directory: temporaryDirectory())

        XCTAssertTrue(controller.enabled)
        XCTAssertFalse(controller.isReady)
        await controller.activateIfNeeded()
        try await waitUntilIdle(controller)

        XCTAssertTrue(controller.enabled)
        XCTAssertTrue(controller.isReady)
        XCTAssertNil(controller.error)
        let activationCalls = await transport.callCount()
        XCTAssertGreaterThan(activationCalls, 0)
    }

    func testDisableDuringSuspendedActivationRemainsDisabledAndIdle() async throws {
        let (suite, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "personalCloudSyncEnabled")
        let transport = ControllerLifecycleTransport()
        await transport.suspendNextAccountIdentifier()
        let controller = makeController(defaults: defaults, transport: transport, directory: temporaryDirectory())

        let activation = Task { await controller.activateIfNeeded() }
        await transport.waitForSuspendedAccountIdentifier()
        XCTAssertTrue(controller.busy)
        await controller.setEnabled(false)
        await transport.releaseAccountIdentifier()
        await activation.value

        XCTAssertFalse(controller.enabled)
        XCTAssertFalse(controller.isReady)
        XCTAssertFalse(controller.busy)
        XCTAssertFalse(defaults.bool(forKey: "personalCloudSyncEnabled"))
    }

    func testOfflineRestartQueuesCachedEditWithoutTransportCallsAndResumesSameAccount() async throws {
        let (suite, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = temporaryDirectory()
        let transport = ControllerLifecycleTransport()
        let seedStore = CloudSyncStore(directory: directory, transport: transport)
        _ = try await seedStore.activate()
        let original = try sampleArchive()
        let queued = try await seedStore.save(original)
        _ = try await seedStore.synchronize()
        let opened = try await seedStore.checkout(dossierID: queued.id)
        await seedStore.deactivate()

        await transport.setOffline(true)
        defaults.set(true, forKey: "personalCloudSyncEnabled")
        let controller = makeController(defaults: defaults, transport: transport, directory: directory)
        await controller.activateIfNeeded()
        XCTAssertFalse(controller.isReady)
        let cached = try await controller.checkout(id: queued.id)
        let callsBeforeQueue = await transport.callCount()
        var edit = cached.archive
        edit.viewState = WorkspaceViewState(search: "Offline bewerking met cache")
        let local = await controller.upload(edit, dossierID: queued.id, baseRevision: opened.revision)
        XCTAssertNotNil(local)
        let callsAfterQueue = await transport.callCount()
        XCTAssertEqual(callsAfterQueue, callsBeforeQueue,
                       "Queueing an already-downloaded dossier while offline must not contact the transport.")

        await transport.setOffline(false)
        await controller.activateIfNeeded()
        XCTAssertTrue(controller.isReady, "The same account can resume and drain its local queue.")
        try await waitUntilIdle(controller)
        await controller.synchronize()
        try await waitUntilIdle(controller)
        let final = try await controller.checkout(id: queued.id)
        XCTAssertEqual(final.archive.viewState?.search, "Offline bewerking met cache")
    }

    func testIndependentWindowAutosavesPersistEachLatestSnapshot() async throws {
        let (suite, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "personalCloudSyncEnabled")
        let transport = ControllerLifecycleTransport()
        let controller = makeController(defaults: defaults, transport: transport,
                                        directory: temporaryDirectory(), autosaveDelay: .milliseconds(10))
        await controller.activateIfNeeded()
        try await waitUntilIdle(controller)
        let original = try sampleArchive()
        var firstArchive = original; firstArchive.viewState = WorkspaceViewState(search: "Venster A laatste wijziging")
        var secondArchive = original; secondArchive.viewState = WorkspaceViewState(search: "Venster B laatste wijziging")
        let firstSaved = await controller.upload(firstArchive, dossierID: nil)
        let secondSaved = await controller.upload(secondArchive, dossierID: nil)
        let first = try XCTUnwrap(firstSaved)
        let second = try XCTUnwrap(secondSaved)
        try await waitUntilIdle(controller)
        let firstWindow = PendingWindowSave(dossierID: first.id, baseRevision: first.revision, archive: firstArchive)
        let secondWindow = PendingWindowSave(dossierID: second.id, baseRevision: second.revision, archive: secondArchive)
        let firstDone = expectation(description: "first window queued its latest edit")
        let secondDone = expectation(description: "second window queued its latest edit")

        firstWindow.archive.viewState = WorkspaceViewState(search: "Venster A uiteindelijke notitie")
        secondWindow.archive.viewState = WorkspaceViewState(search: "Venster B uiteindelijke notitie")
        controller.scheduleUpload(workspaceID: UUID(), archive: { firstWindow.archive },
                                  binding: { (firstWindow.dossierID, firstWindow.baseRevision) }, revision: UUID()) { item in
            firstWindow.dossierID = item.id; firstWindow.baseRevision = item.revision; firstDone.fulfill()
        }
        controller.scheduleUpload(workspaceID: UUID(), archive: { secondWindow.archive },
                                  binding: { (secondWindow.dossierID, secondWindow.baseRevision) }, revision: UUID()) { item in
            secondWindow.dossierID = item.id; secondWindow.baseRevision = item.revision; secondDone.fulfill()
        }
        await fulfillment(of: [firstDone, secondDone], timeout: 3)

        let firstResult = try await controller.checkout(id: firstWindow.dossierID)
        let secondResult = try await controller.checkout(id: secondWindow.dossierID)
        XCTAssertEqual(firstResult.archive.viewState?.search, "Venster A uiteindelijke notitie")
        XCTAssertEqual(secondResult.archive.viewState?.search, "Venster B uiteindelijke notitie")
    }

    func testAccountChangeDuringRefreshDisablesSyncAndInvalidatesBindingEpoch() async throws {
        let (suite, defaults) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "personalCloudSyncEnabled")
        let transport = ControllerLifecycleTransport()
        let controller = makeController(defaults: defaults, transport: transport, directory: temporaryDirectory())
        await controller.activateIfNeeded()
        try await waitUntilIdle(controller)
        let priorEpoch = controller.activationID
        await transport.setAccount("account-B")

        for _ in 0..<100 where controller.enabled {
            await controller.refresh()
            if controller.enabled { try await Task.sleep(for: .milliseconds(10)) }
        }

        XCTAssertFalse(controller.enabled)
        XCTAssertFalse(controller.isReady)
        XCTAssertFalse(controller.busy)
        XCTAssertNotEqual(controller.activationID, priorEpoch)
        XCTAssertTrue(controller.dossiers.isEmpty)
        XCTAssertFalse(defaults.bool(forKey: "personalCloudSyncEnabled"))
    }

    private func makeController(defaults: UserDefaults, transport: ControllerLifecycleTransport,
                                directory: URL, autosaveDelay: Duration = .seconds(2)) -> CloudSyncController {
        let library = CommitteeLibrary(defaults: defaults, storageKey: "controller-test-committees")
        return CloudSyncController(defaults: defaults, committeeLibrary: library, autosaveDelay: autosaveDelay) {
            CloudSyncStore(directory: directory, transport: transport)
        }
    }

    private func isolatedDefaults() -> (String, UserDefaults) {
        let suite = "CloudSyncControllerLifecycleTests-\(UUID().uuidString)"
        return (suite, UserDefaults(suiteName: suite)!)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func sampleArchive() throws -> WorkspaceArchive {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/mac-v1.spdfwork")
        return try WorkspaceArchive.read(url)
    }

    private func waitUntilIdle(_ controller: CloudSyncController) async throws {
        for _ in 0..<300 {
            if !controller.busy { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Cloud controller did not become idle in time.")
    }
}
