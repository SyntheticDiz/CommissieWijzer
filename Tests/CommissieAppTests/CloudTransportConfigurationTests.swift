import XCTest
import CloudKit
@testable import CommissieWijzer

final class CloudTransportConfigurationTests: XCTestCase {
    func testUnconfiguredTestBundleDoesNotConstructCloudContainer() async {
        do {
            _ = try await CloudKitSyncTransport(configurationCheck: { false }).accountIdentifier()
            XCTFail("An unsigned/test bundle must not access CloudKit")
        } catch CloudSyncError.previewBuild {
            // A missing signed capability is an ordinary recoverable state.
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testCloudErrorsDoNotExposeServerDiagnostics() {
        let privateDetails = "private-document-name secret-account-id /private/local-file"
        let error = CKError(.networkFailure, userInfo: [NSLocalizedDescriptionKey: privateDetails])
        let message = CloudKitSyncTransport.presentable(error).localizedDescription
        XCTAssertFalse(message.contains(privateDetails))
        XCTAssertTrue(message.contains("lokale"))
        XCTAssertTrue(message.contains("synchronisatie"))
    }

    func testServerConflictIsDistinguishedFromConnectivityFailure() {
        guard case CloudSyncError.conflict = CloudKitSyncTransport.presentable(CKError(.serverRecordChanged)) else {
            return XCTFail("A conditional write conflict must trigger preservation of both versions")
        }
        let quota = CloudKitSyncTransport.presentable(CKError(.quotaExceeded)).localizedDescription
        XCTAssertTrue(quota.contains("vol"))
        XCTAssertTrue(quota.contains("behouden"))
    }
}
