import XCTest
@testable import CommissieWijzer

private actor LifecycleCloudTransport: CloudSyncTransport {
    private var revision = 0
    private var archives: [UUID: (CloudRemoteDossier, Data)] = [:]
    private var offline = false
    private var calls = 0
    func setOffline(_ value: Bool) { offline = value }
    func callCount() -> Int { calls }
    func accountIdentifier() async throws -> String {
        calls += 1
        if offline { throw CloudSyncError.unavailable }
        return "lifecycle-fixture"
    }
    func listDossiers() async throws -> [CloudRemoteDossier] { calls += 1; return archives.values.map(\.0) }
    func fetchArchive(id: UUID) async throws -> CloudArchiveDownload {
        calls += 1
        guard let value = archives[id] else { throw CloudSyncError.dossierMissing }
        return CloudArchiveDownload(archive: value.1, metadata: value.0)
    }
    func saveArchive(id: UUID, title: String, modifiedAt: Date, contentHash: String,
                     expectedRevision: String?, archive: Data) async throws -> CloudRemoteDossier {
        calls += 1
        if let current = archives[id], current.0.revision != expectedRevision { throw CloudSyncError.conflict }
        if archives[id] == nil, expectedRevision != nil { throw CloudSyncError.conflict }
        revision += 1
        let value = CloudRemoteDossier(id: id, title: title, modifiedAt: modifiedAt,
                                       revision: "lifecycle-\(revision)", contentHash: contentHash)
        archives[id] = (value, archive)
        return value
    }
    func listCommitteeVersions() async throws -> [CloudRemoteCommitteeVersion] { calls += 1; return [] }
    func fetchCommittees(id: UUID) async throws -> CloudCommitteeDownload { calls += 1; throw CloudSyncError.dossierMissing }
    func saveCommittees(id: UUID, modifiedAt: Date, contentHash: String,
                        expectedRevision: String?, payload: Data) async throws -> CloudRemoteCommitteeVersion {
        calls += 1
        throw CloudSyncError.unavailable
    }
}

@MainActor
final class CloudSyncLifecycleTests: XCTestCase {
    func testCloudFlushPersistsLatestNoteAndSourceAndMarksLocalWorkspaceClean() async throws {
        let fixture = try sampleArchiveURL()
        let source = try WorkspaceArchive.read(fixture)
        let controller = try await activeController()
        let uploaded = await controller.upload(source, dossierID: nil)
        let dossier = try XCTUnwrap(uploaded)
        let checkout = try await controller.checkout(id: dossier.id)

        let workspace = SimpleWorkspace()
        try workspace.restore(checkout.archive, persist: false)
        workspace.bindCloudDossier(dossier.id, baseRevision: checkout.revision)
        let note = "Aantekening vóór achtergrondpauze"
        workspace.annotations["fixture-lifecycle-note"] = PointAnnotation(note: note)
        workspace.markDirty()
        workspace.updateTerminationSnapshot(readingPage: 2, viewState: WorkspaceViewState())

        try await workspace.persistCloudWorkIfNeeded(using: controller)

        XCTAssertFalse(workspace.hasUnsavedChanges)
        let saved = try await controller.checkout(id: try XCTUnwrap(workspace.cloudDossierID))
        XCTAssertEqual(saved.archive.annotations["fixture-lifecycle-note"]?.note, note)
        XCTAssertEqual(saved.archive.pdf, source.pdf)
        XCTAssertEqual(saved.archive.page, 2)
        XCTAssertEqual(saved.archive.readings.count, source.readings.count)
    }

    func testExternalWorkdocumentRemainsDirtyUntilItsFileAutosaveCompletes() async throws {
        let fixture = try sampleArchiveURL()
        let archive = try WorkspaceArchive.read(fixture)
        let controller = try await activeController()
        let uploaded = await controller.upload(archive, dossierID: nil)
        let dossier = try XCTUnwrap(uploaded)
        let checkout = try await controller.checkout(id: dossier.id)

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("CloudLifecycle-\(UUID().uuidString).spdfwork")
        try archive.write(file)
        let workspace = SimpleWorkspace()
        workspace.openWorkspace(at: file)
        try await waitUntilLoaded(workspace)
        let openedURL = try XCTUnwrap(workspace.openedWorkdocumentURL)
        defer { try? FileManager.default.removeItem(at: openedURL) }
        workspace.bindCloudDossier(dossier.id, baseRevision: checkout.revision)
        workspace.annotations["fixture-lifecycle-note"] = PointAnnotation(note: "Wijziging via dossierkoppeling")
        workspace.markDirty()

        try await workspace.persistCloudWorkIfNeeded(using: controller)
        XCTAssertTrue(workspace.isOpenedWorkdocument)
        XCTAssertTrue(workspace.hasUnsavedChanges, "A cloud queue write must not claim the external .spdfwork file is saved.")

        try await workspace.autosaveOpenedWorkdocument()
        XCTAssertFalse(workspace.hasUnsavedChanges)
        let local = try WorkspaceArchive.read(openedURL)
        XCTAssertEqual(local.annotations["fixture-lifecycle-note"]?.note, "Wijziging via dossierkoppeling")
    }

    func testUnlinkedAndDisabledDossiersNeverBecomeClean() async throws {
        let archive = try WorkspaceArchive.read(sampleArchiveURL())
        let defaults = try isolatedDefaults()
        defer { if let name = defaults.string(forKey: "testSuiteName") { defaults.removePersistentDomain(forName: name) } }
        let controller = CloudSyncController(defaults: defaults) {
            XCTFail("A disabled controller must not construct a cloud store.")
            return CloudSyncStore(directory: FileManager.default.temporaryDirectory,
                                  transport: LifecycleCloudTransport())
        }

        let unlinked = SimpleWorkspace()
        try unlinked.restore(archive, persist: false)
        unlinked.annotations["fixture-lifecycle-note"] = PointAnnotation(note: "Unlinked")
        unlinked.markDirty()
        try await unlinked.persistCloudWorkIfNeeded(using: controller)
        XCTAssertTrue(unlinked.hasUnsavedChanges)

        let disabledLinked = SimpleWorkspace()
        try disabledLinked.restore(archive, persist: false)
        disabledLinked.bindCloudDossier(UUID(), baseRevision: "old-checkout")
        disabledLinked.annotations["fixture-lifecycle-note"] = PointAnnotation(note: "Offline")
        disabledLinked.markDirty()
        try await disabledLinked.persistCloudWorkIfNeeded(using: controller)
        XCTAssertTrue(disabledLinked.hasUnsavedChanges)
        XCTAssertFalse(controller.isReady)
    }

    func testOfflineCloudOpenHasIndependentLocalWorkingCopyAndQueuesWithoutNetwork() async throws {
        let archive = try WorkspaceArchive.read(sampleArchiveURL())
        let transport = LifecycleCloudTransport()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let seedStore = CloudSyncStore(directory: directory, transport: transport)
        _ = try await seedStore.activate()
        let queued = try await seedStore.save(archive)
        _ = try await seedStore.synchronize()
        let checkout = try await seedStore.checkout(dossierID: queued.id)
        await seedStore.deactivate()
        await transport.setOffline(true)

        let defaults = try isolatedDefaults()
        defaults.set(true, forKey: "personalCloudSyncEnabled")
        defer { if let name = defaults.string(forKey: "testSuiteName") { defaults.removePersistentDomain(forName: name) } }
        let controller = CloudSyncController(defaults: defaults) {
            CloudSyncStore(directory: directory, transport: transport)
        }
        await controller.activateIfNeeded()
        XCTAssertFalse(controller.isReady)
        let callsBeforeLocalWork = await transport.callCount()

        let workspace = SimpleWorkspace()
        try await workspace.openCloudCheckout(checkout, using: controller)
        let workingURL = try XCTUnwrap(workspace.openedWorkdocumentURL)
        defer { try? FileManager.default.removeItem(at: workingURL) }
        XCTAssertNotEqual(workingURL.deletingLastPathComponent(), directory)
        XCTAssertEqual(workspace.cloudDossierID, checkout.dossierID,
                       "An enabled but offline session keeps the cached dossier binding for local queueing.")
        workspace.annotations["fixture-lifecycle-note"] = PointAnnotation(note: "Offline bewaarde notitie")
        workspace.markDirty()

        try await workspace.persistCloudWorkIfNeeded(using: controller)
        XCTAssertTrue(workspace.hasUnsavedChanges, "A queued cloud save does not replace the local file autosave.")
        try await workspace.autosaveOpenedWorkdocument()

        let callsAfterLocalWork = await transport.callCount()
        XCTAssertEqual(callsAfterLocalWork, callsBeforeLocalWork, "Offline checkout, queueing and local autosave must not contact the transport.")
        let local = try WorkspaceArchive.read(workingURL)
        XCTAssertEqual(local.annotations["fixture-lifecycle-note"]?.note, "Offline bewaarde notitie")
        let cached = try await controller.checkout(id: checkout.dossierID)
        XCTAssertEqual(cached.archive.annotations["fixture-lifecycle-note"]?.note, "Offline bewaarde notitie")
    }

    func testOptedOutCloudCheckoutStaysLocalAndUsesNativeWorkdocumentSave() async throws {
        let archive = try WorkspaceArchive.read(sampleArchiveURL())
        let controller = try await activeController()
        let uploaded = await controller.upload(archive, dossierID: nil)
        let dossier = try XCTUnwrap(uploaded)
        let checkout = try await controller.checkout(id: dossier.id)
        await controller.setEnabled(false)

        let workspace = SimpleWorkspace()
        try await workspace.openCloudCheckout(checkout, using: controller)
        let localURL = try XCTUnwrap(workspace.openedWorkdocumentURL)
        defer { try? FileManager.default.removeItem(at: localURL) }
        XCTAssertNil(workspace.cloudDossierID, "Opening a cached dossier while global sync is off must not bind it for later upload.")
        workspace.annotations["fixture-lifecycle-note"] = PointAnnotation(note: "Alleen lokaal opgeslagen")
        workspace.markDirty()

        try await workspace.persistCloudWorkIfNeeded(using: controller)
        XCTAssertTrue(workspace.hasUnsavedChanges)
        try await workspace.autosaveOpenedWorkdocument()
        XCTAssertFalse(workspace.hasUnsavedChanges)
        XCTAssertEqual(try WorkspaceArchive.read(localURL).annotations["fixture-lifecycle-note"]?.note,
                       "Alleen lokaal opgeslagen")
    }

    private func activeController() async throws -> CloudSyncController {
        let defaults = try isolatedDefaults()
        defaults.set(true, forKey: "personalCloudSyncEnabled")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let transport = LifecycleCloudTransport()
        let controller = CloudSyncController(defaults: defaults) {
            CloudSyncStore(directory: directory, transport: transport)
        }
        await controller.activateIfNeeded()
        XCTAssertTrue(controller.isReady)
        return controller
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "CloudSyncLifecycleTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else { throw CocoaError(.fileReadUnknown) }
        defaults.set(name, forKey: "testSuiteName")
        return defaults
    }

    private func sampleArchiveURL() throws -> URL {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/mac-v1.spdfwork")
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        return url
    }

    private func waitUntilLoaded(_ workspace: SimpleWorkspace) async throws {
        for _ in 0..<200 {
            if !workspace.exporting, workspace.document != nil, workspace.isOpenedWorkdocument { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(workspace.document)
        XCTAssertTrue(workspace.isOpenedWorkdocument)
    }
}
