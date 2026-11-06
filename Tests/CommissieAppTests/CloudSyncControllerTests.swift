import XCTest
@testable import CommissieWijzer

@MainActor
final class CloudSyncControllerTests: XCTestCase {
    func testSyncDefaultsOffWithoutConstructingCloudStore() {
        let suite = "CloudSyncControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var storeConstructed = false
        let controller = CloudSyncController(defaults: defaults) {
            storeConstructed = true
            return CloudSyncStore(directory: FileManager.default.temporaryDirectory,
                                  transport: CloudKitSyncTransport(configurationCheck: { false }))
        }
        XCTAssertFalse(controller.enabled)
        XCTAssertNil(defaults.object(forKey: "personalCloudSyncEnabled"))
        XCTAssertFalse(storeConstructed, "Default-off startup must not construct a cloud store.")
    }

    func testChangingWorkspaceIdentityClearsDossierBinding() {
        let workspace = SimpleWorkspace()
        workspace.bindCloudDossier(UUID(), baseRevision: "checkout")
        XCTAssertNotNil(workspace.cloudDossierID)
        workspace.documentID = UUID()
        XCTAssertNil(workspace.cloudDossierID)
        XCTAssertNil(workspace.cloudBaseRevision)
    }
}
