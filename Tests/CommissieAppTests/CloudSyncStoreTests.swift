import XCTest
import CryptoKit
@testable import CommissieWijzer

private actor MockCloudSyncTransport: CloudSyncTransport {
    private var account = "fixture-account-one"
    private var calls = 0
    private var nextRevision = 0
    private var archives: [UUID: (CloudRemoteDossier, Data)] = [:]
    private var committees: [UUID: (CloudRemoteCommitteeVersion, Data)] = [:]
    private var blockFetch = false
    private var fetchStarted = false
    private var fetchStartedWaiter: CheckedContinuation<Void, Never>?
    private var fetchRelease: CheckedContinuation<Void, Never>?
    private var blockSave = false
    private var saveStarted = false
    private var saveStartedWaiter: CheckedContinuation<Void, Never>?
    private var saveRelease: CheckedContinuation<Void, Never>?

    func setAccount(_ value: String) { account = value }
    func callCount() -> Int { calls }
    func remoteDossierCount() -> Int { archives.count }
    func blockNextArchiveFetch() { blockFetch = true; fetchStarted = false }
    func waitForArchiveFetch() async {
        if fetchStarted { return }
        await withCheckedContinuation { fetchStartedWaiter = $0 }
    }
    func releaseArchiveFetch() { fetchRelease?.resume(); fetchRelease = nil }
    func blockNextArchiveSave() { blockSave = true; saveStarted = false }
    func waitForArchiveSave() async {
        if saveStarted { return }
        await withCheckedContinuation { saveStartedWaiter = $0 }
    }
    func releaseArchiveSave() { saveRelease?.resume(); saveRelease = nil }

    func accountIdentifier() async throws -> String { calls += 1; return account }
    func listDossiers() async throws -> [CloudRemoteDossier] { calls += 1; return archives.values.map(\.0) }
    func fetchArchive(id: UUID) async throws -> CloudArchiveDownload {
        calls += 1
        guard let value = archives[id] else { throw CloudSyncError.dossierMissing }
        if blockFetch {
            blockFetch = false; fetchStarted = true
            fetchStartedWaiter?.resume(); fetchStartedWaiter = nil
            await withCheckedContinuation { fetchRelease = $0 }
        }
        return CloudArchiveDownload(archive: value.1, metadata: value.0)
    }
    func saveArchive(id: UUID, title: String, modifiedAt: Date, contentHash: String,
                     expectedRevision: String?, archive: Data) async throws -> CloudRemoteDossier {
        calls += 1
        if let current = archives[id] {
            guard current.0.revision == expectedRevision else { throw CloudSyncError.conflict }
        } else if expectedRevision != nil { throw CloudSyncError.conflict }
        if blockSave {
            blockSave = false; saveStarted = true
            saveStartedWaiter?.resume(); saveStartedWaiter = nil
            await withCheckedContinuation { saveRelease = $0 }
            if let current = archives[id] {
                guard current.0.revision == expectedRevision else { throw CloudSyncError.conflict }
            } else if expectedRevision != nil { throw CloudSyncError.conflict }
        }
        nextRevision += 1
        let meta = CloudRemoteDossier(id: id, title: title, modifiedAt: modifiedAt,
                                      revision: "r\(nextRevision)", contentHash: contentHash)
        archives[id] = (meta, archive)
        return meta
    }
    func listCommitteeVersions() async throws -> [CloudRemoteCommitteeVersion] { calls += 1; return committees.values.map(\.0) }
    func fetchCommittees(id: UUID) async throws -> CloudCommitteeDownload {
        calls += 1
        guard let value = committees[id] else { throw CloudSyncError.dossierMissing }
        return CloudCommitteeDownload(payload: value.1, metadata: value.0)
    }
    func saveCommittees(id: UUID, modifiedAt: Date, contentHash: String,
                        expectedRevision: String?, payload: Data) async throws -> CloudRemoteCommitteeVersion {
        calls += 1
        if let current = committees[id] {
            guard current.0.revision == expectedRevision else { throw CloudSyncError.conflict }
        } else if expectedRevision != nil { throw CloudSyncError.conflict }
        nextRevision += 1
        let meta = CloudRemoteCommitteeVersion(id: id, modifiedAt: modifiedAt,
                                               revision: "r\(nextRevision)", contentHash: contentHash)
        committees[id] = (meta, payload)
        return meta
    }

    func seed(_ archive: WorkspaceArchive, id: UUID) throws -> CloudRemoteDossier {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var value = archive; value.snapshotID = nil
        let data = try encoder.encode(value)
        nextRevision += 1
        let meta = CloudRemoteDossier(id: id, title: value.name, modifiedAt: Date(),
            revision: "r\(nextRevision)", contentHash: Self.hash(data))
        archives[id] = (meta, data)
        return meta
    }
    func seedRaw(_ data: Data, id: UUID, title: String) -> CloudRemoteDossier {
        nextRevision += 1
        let meta = CloudRemoteDossier(id: id, title: title, modifiedAt: Date(), revision: "r\(nextRevision)", contentHash: Self.hash(data))
        archives[id] = (meta, data)
        return meta
    }
    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class CloudSyncStoreTests: XCTestCase {
    func testAccountChangedWhileAppWasClosedNeedsFreshOptInAndKeepsOldQueueSeparate() async throws {
        let directory = temporaryDirectory(), transport = MockCloudSyncTransport()
        let old = CloudSyncStore(directory: directory, transport: transport)
        _ = try await old.activate()
        _ = try await old.save(try sampleArchive())
        await old.deactivate()
        await transport.setAccount("fixture-new-account")
        let restarted = CloudSyncStore(directory: directory, transport: transport)
        do { _ = try await restarted.activate(); XCTFail("Remembered opt-in must not migrate to a different account") }
        catch { guard case CloudSyncError.accountChanged = error else { return XCTFail("Unexpected error: \(error)") } }
        let newAccount = try await restarted.activate(allowAccountChange: true)
        XCTAssertTrue(newAccount.isEmpty)
        _ = try await restarted.synchronize()
        let remoteCount = await transport.remoteDossierCount()
        XCTAssertEqual(remoteCount, 0)
    }

    func testCommitteeOptOutKeepsQueuedProfilesLocalAndOptInTransfersVersions() async throws {
        let transport = MockCloudSyncTransport()
        let first = CloudSyncStore(directory: temporaryDirectory(), transport: transport)
        _ = try await first.activate()
        let purpose = MeetingPurpose(committee: CommitteeDefinition(name: "Fictieve wooncommissie", topics: ["Wonen", "Bereikbaarheid"], attention: "Controleer de planning."))
        try await first.saveCommittees([purpose])
        _ = try await first.synchronize(includeCommittees: false)
        let withheld = try await transport.listCommitteeVersions()
        XCTAssertTrue(withheld.isEmpty)
        _ = try await first.synchronize(includeCommittees: true)
        try await first.saveCommittees([purpose])
        let unchanged = try await first.committeeVersions()
        XCTAssertEqual(unchanged.count, 1, "Unchanged profiles must not create a new version at every startup")
        try await first.saveCommittees([purpose, .bestuur])
        _ = try await first.synchronize(includeCommittees: true)

        let second = CloudSyncStore(directory: temporaryDirectory(), transport: transport)
        _ = try await second.activate()
        _ = try await second.synchronize(includeCommittees: true)
        let versions = try await second.committeeVersions()
        XCTAssertEqual(versions.count, 2)
        XCTAssertTrue(versions.contains(where: { $0.committees == [purpose, .bestuur] }))
        await second.deactivate()
        let callsBeforeOfflineRead = await transport.callCount()
        let offlineVersions = try await second.committeeVersions()
        let callsAfterOfflineRead = await transport.callCount()
        XCTAssertEqual(offlineVersions.count, 2)
        XCTAssertEqual(callsBeforeOfflineRead, callsAfterOfflineRead)
    }

    func testOfflineQueueRequiresExistingDownloadedDossierInCachedAccount() async throws {
        let directory = temporaryDirectory(), transport = MockCloudSyncTransport()
        let seed = CloudSyncStore(directory: directory, transport: transport)
        _ = try await seed.activate()
        let archive = try sampleArchive()
        let queued = try await seed.save(archive)
        let checkout = try await seed.checkout(dossierID: queued.id)
        await seed.deactivate()
        let restarted = CloudSyncStore(directory: directory, transport: transport)
        let before = await transport.callCount()
        for id in [nil, UUID()] as [UUID?] {
            do {
                _ = try await restarted.save(archive, dossierID: id, allowOfflineCache: true)
                XCTFail("An offline cache cannot admit a new or unrelated dossier")
            } catch { guard case CloudSyncError.notActivated = error else { return XCTFail("Unexpected error: \(error)") } }
        }
        var edited = checkout.archive
        edited.analysisModel = "offline-local-edit"
        _ = try await restarted.save(edited, dossierID: queued.id, baseRevision: checkout.revision, allowOfflineCache: true)
        let saved = try await restarted.checkout(dossierID: queued.id)
        XCTAssertEqual(saved.archive.analysisModel, "offline-local-edit")
        let after = await transport.callCount()
        XCTAssertEqual(before, after)
        await transport.setAccount("fixture-other-account")
        do { _ = try await restarted.activate(); XCTFail("Offline edits must remain in the original account") }
        catch { guard case CloudSyncError.accountChanged = error else { return XCTFail("Unexpected error: \(error)") } }
    }

    func testCloudTransportIsUntouchedUntilExplicitActivation() async throws {
        let transport = MockCloudSyncTransport()
        let store = CloudSyncStore(directory: temporaryDirectory(), transport: transport)
        let initialCalls = await transport.callCount()
        XCTAssertEqual(initialCalls, 0)
        let unboundList = try await store.dossiers()
        XCTAssertTrue(unboundList.isEmpty)
        let callsAfterListing = await transport.callCount()
        XCTAssertEqual(callsAfterListing, 0)
    }

    func testNativeWriterRejectsMalformedOptionalSupplementsBeforeQueueing() async throws {
        let store = CloudSyncStore(directory: temporaryDirectory(), transport: MockCloudSyncTransport())
        _ = try await store.activate()
        var malformed = try sampleArchive()
        malformed.savedChatThreads = [SavedChatThread(id: "bad-cloud-thread", pages: [999], model: "fixture",
            focus: "", wholeDocument: false, passage: nil, messages: [])]
        do { _ = try await store.save(malformed); XCTFail("Invalid supplements must be rejected like a local archive write.") }
        catch { guard case CloudSyncError.invalidArchive = error else { return XCTFail("Unexpected error: \(error)") } }
        let pending = try await store.dossiers()
        XCTAssertTrue(pending.isEmpty)
    }

    func testEquivalentSnapshotsHaveStableHashAcrossSnapshotIDsAndSetOrder() async throws {
        let store = CloudSyncStore(directory: temporaryDirectory(), transport: MockCloudSyncTransport())
        _ = try await store.activate()
        let base = try sampleArchive()
        let firstArchive = try variant(base, snapshotID: UUID(), starred: ["fixture-z", "fixture-a", "fixture-m"])
        let first = try await store.save(firstArchive)
        let equivalent = try variant(base, snapshotID: UUID(), starred: ["fixture-m", "fixture-z", "fixture-a"])
        let second = try await store.save(equivalent, dossierID: first.id, baseRevision: first.revision)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.revision, first.revision)
    }

    func testQueuedSnapshotSurvivesDisableAndStoreRecreation() async throws {
        let root = temporaryDirectory()
        let transport = MockCloudSyncTransport()
        let archive = try sampleArchive()
        let store = CloudSyncStore(directory: root, transport: transport)
        _ = try await store.activate()
        let saved = try await store.save(archive)
        XCTAssertTrue(saved.hasLocalChanges)
        await store.deactivate()

        let restarted = CloudSyncStore(directory: root, transport: transport)
        let cached = try await restarted.dossiers()
        XCTAssertEqual(cached.map(\.id), [saved.id])
        let cachedArchive = try await restarted.archive(dossierID: saved.id)
        XCTAssertEqual(cachedArchive.name, archive.name)
        let before = await transport.callCount()
        XCTAssertEqual(before, 2, "Reading a disabled cache must make no cloud calls.")

        _ = try await restarted.activate()
        _ = try await restarted.synchronize()
        let finalDossiers = try await restarted.dossiers()
        XCTAssertFalse(try XCTUnwrap(finalDossiers.first).hasLocalChanges)
    }

    func testStaleCheckoutKeepsLocalAndRemoteVersions() async throws {
        let root = temporaryDirectory()
        let transport = MockCloudSyncTransport()
        let id = UUID()
        let original = try sampleArchive()
        let base = try await transport.seed(original, id: id)
        let store = CloudSyncStore(directory: root, transport: transport)
        _ = try await store.activate()
        _ = try await store.synchronize()
        let checkout = try await store.checkout(dossierID: id)

        var localEdit = checkout.archive
        localEdit.analysisModel = "local-device-fixture"
        let queued = try await store.save(localEdit, dossierID: id, baseRevision: checkout.revision)
        XCTAssertTrue(queued.hasLocalChanges)

        var remoteEdit = original
        remoteEdit.analysisModel = "remote-device-fixture"
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        remoteEdit.snapshotID = nil
        let remoteBytes = try encoder.encode(remoteEdit)
        let remoteHash = SHA256.hash(data: remoteBytes).map { String(format: "%02x", $0) }.joined()
        _ = try await transport.saveArchive(id: id, title: remoteEdit.name, modifiedAt: Date(),
            contentHash: remoteHash, expectedRevision: base.revision, archive: remoteBytes)

        let final = try await store.synchronize()
        let conflict = try XCTUnwrap(final.first(where: { $0.id != id }))
        XCTAssertTrue(conflict.isConflict)
        let remoteArchive = try await store.archive(dossierID: id)
        let localArchive = try await store.archive(dossierID: conflict.id)
        XCTAssertEqual(remoteArchive.analysisModel, "remote-device-fixture")
        XCTAssertEqual(localArchive.analysisModel, "local-device-fixture")
    }

    func testUploadedOpenDocumentCanKeepSavingButOlderWindowTokenForks() async throws {
        let root = temporaryDirectory()
        let transport = MockCloudSyncTransport()
        let store = CloudSyncStore(directory: root, transport: transport)
        _ = try await store.activate()
        let initial = try sampleArchive()
        let first = try await store.save(initial)
        let firstCheckout = try await store.checkout(dossierID: first.id)

        var edit = firstCheckout.archive
        edit.analysisModel = "first-local-fixture"
        let queued = try await store.save(edit, dossierID: first.id, baseRevision: firstCheckout.revision)
        XCTAssertEqual(queued.id, first.id)
        _ = try await store.synchronize()

        let currentCheckout = try await store.checkout(dossierID: first.id)
        var followup = currentCheckout.archive
        followup.analysisModel = "second-local-fixture"
        let sameDocument = try await store.save(followup, dossierID: first.id, baseRevision: currentCheckout.revision)
        XCTAssertEqual(sameDocument.id, first.id)

        var staleWindow = currentCheckout.archive
        staleWindow.analysisModel = "stale-window-fixture"
        let fork = try await store.save(staleWindow, dossierID: first.id, baseRevision: firstCheckout.revision)
        XCTAssertNotEqual(fork.id, first.id)
        XCTAssertTrue(fork.isConflict)
    }

    func testEditQueuedDuringUploadAdvancesParentCASWithoutLosingChild() async throws {
        let transport = MockCloudSyncTransport()
        let store = CloudSyncStore(directory: temporaryDirectory(), transport: transport)
        _ = try await store.activate()
        let initial = try sampleArchive()
        let saved = try await store.save(initial)
        let checkout = try await store.checkout(dossierID: saved.id)
        var uploadedSnapshot = checkout.archive
        uploadedSnapshot.analysisModel = "upload-parent-fixture"
        let queuedParent = try await store.save(uploadedSnapshot, dossierID: saved.id, baseRevision: checkout.revision)

        await transport.blockNextArchiveSave()
        let firstSync = Task { try await store.synchronize() }
        await transport.waitForArchiveSave()
        var child = uploadedSnapshot
        child.analysisModel = "queued-child-fixture"
        let queuedChild = try await store.save(child, dossierID: saved.id, baseRevision: queuedParent.revision)
        XCTAssertEqual(queuedChild.id, saved.id)
        await transport.releaseArchiveSave()
        let afterFirstUpload = try await firstSync.value
        let entryAfterFirstUpload = try XCTUnwrap(afterFirstUpload.first(where: { $0.id == saved.id }))
        XCTAssertTrue(entryAfterFirstUpload.hasLocalChanges)
        XCTAssertFalse(afterFirstUpload.contains(where: \.isConflict))

        _ = try await store.synchronize()
        let finalEntries = try await store.dossiers()
        XCTAssertEqual(finalEntries.count, 1)
        XCTAssertFalse(try XCTUnwrap(finalEntries.first).hasLocalChanges)
        let remote = try await transport.listDossiers()
        XCTAssertEqual(remote.count, 1)
        let finalArchive = try await store.archive(dossierID: saved.id)
        XCTAssertEqual(finalArchive.analysisModel, "queued-child-fixture")
    }

    func testDownloadedCacheRefreshesToRemoteVersionAndRemainsReadableOffline() async throws {
        let root = temporaryDirectory(), transport = MockCloudSyncTransport(), id = UUID()
        let original = try sampleArchive()
        _ = try await transport.seed(original, id: id)
        let store = CloudSyncStore(directory: root, transport: transport)
        _ = try await store.activate(); _ = try await store.synchronize()
        _ = try await store.checkout(dossierID: id)

        var remote = original; remote.analysisModel = "newer-remote-fixture"
        let remoteBytes = try Self.encode(remote)
        let remoteHash = Self.hash(remoteBytes)
        let currentRemoteDossiers = try await transport.listDossiers()
        let current = try XCTUnwrap(currentRemoteDossiers.first)
        _ = try await transport.saveArchive(id: id, title: remote.name, modifiedAt: Date(),
            contentHash: remoteHash, expectedRevision: current.revision, archive: remoteBytes)
        _ = try await store.synchronize()
        await store.deactivate()
        let offline = try await store.archive(dossierID: id)
        XCTAssertEqual(offline.analysisModel, "newer-remote-fixture")
    }

    func testLocalEditDuringSuspendedRemoteDownloadIsNotOverwritten() async throws {
        let root = temporaryDirectory(), transport = MockCloudSyncTransport(), id = UUID()
        let original = try sampleArchive(); let base = try await transport.seed(original, id: id)
        let store = CloudSyncStore(directory: root, transport: transport)
        _ = try await store.activate(); _ = try await store.synchronize()
        let checkout = try await store.checkout(dossierID: id)
        var remote = original; remote.analysisModel = "other-device-fixture"
        let bytes = try Self.encode(remote)
        _ = try await transport.saveArchive(id: id, title: remote.name, modifiedAt: Date(),
            contentHash: Self.hash(bytes), expectedRevision: base.revision, archive: bytes)
        await transport.blockNextArchiveFetch()
        let task = Task { try await store.synchronize() }
        await transport.waitForArchiveFetch()

        var local = checkout.archive; local.analysisModel = "this-device-fixture"
        _ = try await store.save(local, dossierID: id, baseRevision: checkout.revision)
        await transport.releaseArchiveFetch()
        _ = try await task.value

        let entries = try await store.dossiers()
        let fork = try XCTUnwrap(entries.first(where: { $0.id != id }))
        XCTAssertTrue(fork.isConflict)
        let remoteArchive = try await store.archive(dossierID: id)
        let localArchive = try await store.archive(dossierID: fork.id)
        XCTAssertEqual(remoteArchive.analysisModel, "other-device-fixture")
        XCTAssertEqual(localArchive.analysisModel, "this-device-fixture")
    }

    func testDisableDuringFetchCannotPublishOrOverwriteOfflineCopy() async throws {
        let root = temporaryDirectory(), transport = MockCloudSyncTransport(), id = UUID()
        let original = try sampleArchive(); let base = try await transport.seed(original, id: id)
        let store = CloudSyncStore(directory: root, transport: transport)
        _ = try await store.activate(); _ = try await store.synchronize()
        _ = try await store.checkout(dossierID: id)
        var remote = original; remote.analysisModel = "remote-fixture"
        let bytes = try Self.encode(remote)
        _ = try await transport.saveArchive(id: id, title: remote.name, modifiedAt: Date(),
            contentHash: Self.hash(bytes), expectedRevision: base.revision, archive: bytes)
        await transport.blockNextArchiveFetch()
        let task = Task { try await store.synchronize() }
        await transport.waitForArchiveFetch()
        await store.deactivate()
        await transport.releaseArchiveFetch()
        do { _ = try await task.value; XCTFail("A disabled fetch must not publish a completion.") }
        catch { guard case CloudSyncError.accountChanged = error else { return XCTFail("Unexpected error: \(error)") } }
        let offline = try await store.archive(dossierID: id)
        XCTAssertEqual(offline.analysisModel, original.analysisModel)
    }

    func testChangedAccountCannotUploadQueuedOldNamespace() async throws {
        let transport = MockCloudSyncTransport(), store = CloudSyncStore(directory: temporaryDirectory(), transport: transport)
        _ = try await store.activate()
        _ = try await store.save(try sampleArchive())
        await transport.setAccount("fixture-account-two")
        do { _ = try await store.synchronize(); XCTFail("A different account must not receive old pending data.") }
        catch { guard case CloudSyncError.accountChanged = error else { return XCTFail("Unexpected error: \(error)") } }
        let remoteCount = await transport.remoteDossierCount()
        XCTAssertEqual(remoteCount, 0)
    }

    func testMalformedRemoteArchiveAndCorruptManifestAreSurfaced() async throws {
        let transport = MockCloudSyncTransport(), id = UUID(), root = temporaryDirectory()
        _ = await transport.seedRaw(Data("not a work document".utf8), id: id, title: "Fictief dossier")
        let store = CloudSyncStore(directory: root, transport: transport)
        _ = try await store.activate(); _ = try await store.synchronize()
        do { _ = try await store.archive(dossierID: id); XCTFail("Malformed remote data must be rejected.") }
        catch { guard case CloudSyncError.invalidArchive = error else { return XCTFail("Unexpected error: \(error)") } }

        let cloudRoot = root.appendingPathComponent("CloudSync")
        let cacheHash = try String(contentsOf: cloudRoot.appendingPathComponent("active-cache"), encoding: .utf8)
        try Data("corrupt".utf8).write(to: cloudRoot.appendingPathComponent(cacheHash).appendingPathComponent("manifest.json"))
        let restarted = CloudSyncStore(directory: root, transport: transport)
        do { _ = try await restarted.activate(); XCTFail("Corrupt persisted metadata must not be hidden.") }
        catch { guard case CloudSyncError.corruptCache = error else { return XCTFail("Unexpected error: \(error)") } }
    }

    private func sampleArchive() throws -> WorkspaceArchive {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/mac-v1.spdfwork")
        var archive = try WorkspaceArchive.read(fixture)
        archive.analysisModel = "fictitious-cloud-test"
        return archive
    }

    private static func encode(_ archive: WorkspaceArchive) throws -> Data {
        var clean = archive; clean.snapshotID = nil
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(clean)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { throw CloudSyncError.invalidArchive }
        if let starred = object["starred"] as? [String] { object["starred"] = starred.sorted() }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func variant(_ archive: WorkspaceArchive, snapshotID: UUID, starred: [String]) throws -> WorkspaceArchive {
        let encoded = try JSONEncoder().encode(archive)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { throw CloudSyncError.invalidArchive }
        object["snapshotID"] = snapshotID.uuidString
        object["starred"] = starred
        return try JSONDecoder().decode(WorkspaceArchive.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
