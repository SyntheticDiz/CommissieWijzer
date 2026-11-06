import Foundation
import XCTest
import UserNotifications
@testable import CommissieWijzer

@MainActor
final class AnalysisCompletionNotificationsTests: XCTestCase {
    func testDefaultPreferenceIsEnabledButDoesNotRequestPermissionUntilAnalysis() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport()

        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)

        XCTAssertTrue(service.isEnabled)
        XCTAssertTrue(defaults.bool(forKey: AnalysisCompletionNotifications.enabledDefaultsKey))
        XCTAssertEqual(transport.authorizationRequestCount, 0)
        service.prepareForAnalysis()
        try await waitUntil { transport.authorizationRequestCount == 1 }
        transport.finishAuthorizationRequest(allowed: true)
        try await waitUntil { service.canDeliverNotifications }
        XCTAssertEqual(transport.authorizationRequestCount, 1)
    }

    func testExplicitEnableRequestsPermissionAndDisableRemovesPendingNotifications() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .notDetermined, alertsAllowed: false)
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)

        let enabling = Task { await service.setEnabled(true) }
        try await waitUntil { transport.authorizationRequestCount == 1 }
        transport.finishAuthorizationRequest(allowed: true)
        await enabling.value
        XCTAssertTrue(service.isEnabled)
        XCTAssertTrue(service.canDeliverNotifications)

        let operationID = UUID()
        await service.postCompletion(id: operationID, outcome: .completed)
        XCTAssertEqual(transport.addedNotifications.count, 1)

        await service.setEnabled(false)
        XCTAssertFalse(service.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: AnalysisCompletionNotifications.enabledDefaultsKey))
        XCTAssertTrue(transport.removedPrefixes.contains("analysis-completion-"))
    }

    func testPrepareCoalescesPermissionRequestsAndCompletionWaitsForPermission() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .notDetermined, alertsAllowed: false)
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)

        service.prepareForAnalysis()
        service.prepareForAnalysis()
        try await waitUntil { transport.authorizationRequestCount == 1 }
        let operationID = UUID()
        let posting = Task { await service.postCompletion(id: operationID, outcome: .completed) }
        await Task.yield()
        XCTAssertEqual(transport.authorizationRequestCount, 1)
        XCTAssertTrue(transport.addedNotifications.isEmpty)

        transport.finishAuthorizationRequest(allowed: true)
        await posting.value
        XCTAssertEqual(transport.authorizationRequestCount, 1)
        XCTAssertEqual(transport.addedNotifications.map(\.identifier), ["analysis-completion-\(operationID.uuidString)"])
    }

    func testCancelDuringPermissionRequestSuppressesLateCompletion() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .notDetermined, alertsAllowed: false)
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)
        let operationID = UUID()

        service.prepareForAnalysis()
        try await waitUntil { transport.authorizationRequestCount == 1 }
        let posting = Task { await service.postCompletion(id: operationID, outcome: .completed) }
        await Task.yield()
        service.cancel(id: operationID)
        transport.finishAuthorizationRequest(allowed: true)
        await posting.value

        XCTAssertTrue(transport.addedNotifications.isEmpty)
        XCTAssertEqual(transport.removedIdentifiers, ["analysis-completion-\(operationID.uuidString)"])
    }

    func testDeniedPermissionAfterPromptNeverAddsNotification() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .notDetermined, alertsAllowed: false)
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)
        let operationID = UUID()

        service.prepareForAnalysis()
        try await waitUntil { transport.authorizationRequestCount == 1 }
        let posting = Task { await service.postCompletion(id: operationID, outcome: .completed) }
        transport.finishAuthorizationRequest(allowed: false)
        await posting.value

        XCTAssertEqual(service.authorizationStatus, .denied)
        XCTAssertFalse(service.canDeliverNotifications)
        XCTAssertTrue(transport.addedNotifications.isEmpty)
    }

    func testCancelDuringAddRemovesLateNotificationAndPreventsDuplicates() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .authorized, alertsAllowed: true)
        transport.holdAdds = true
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)
        await service.refreshAuthorization()
        let operationID = UUID()

        let posting = Task { await service.postCompletion(id: operationID, outcome: .completedWithWarnings) }
        try await waitUntil { transport.addStartedCount == 1 }
        service.cancel(id: operationID)
        transport.finishAdd()
        await posting.value

        XCTAssertEqual(transport.addedNotifications.count, 1)
        XCTAssertTrue(transport.removedIdentifiers.contains("analysis-completion-\(operationID.uuidString)"))
        await service.postCompletion(id: operationID, outcome: .completed)
        XCTAssertEqual(transport.addedNotifications.count, 1)
    }

    func testDisablingWhileAddIsPendingRemovesLateNotification() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .authorized, alertsAllowed: true)
        transport.holdAdds = true
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)
        await service.refreshAuthorization()
        let operationID = UUID()

        let posting = Task { await service.postCompletion(id: operationID, outcome: .completed) }
        try await waitUntil { transport.addStartedCount == 1 }
        await service.setEnabled(false)
        transport.finishAdd()
        await posting.value

        XCTAssertFalse(service.isEnabled)
        XCTAssertTrue(transport.removedPrefixes.contains("analysis-completion-"))
        XCTAssertTrue(transport.removedIdentifiers.contains("analysis-completion-\(operationID.uuidString)"))
    }

    func testOnlySuccessfulOutcomesPostGenericNotificationCopy() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .authorized, alertsAllowed: true)
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)
        await service.refreshAuthorization()

        await service.postCompletion(id: UUID(), outcome: .failed)
        await service.postCompletion(id: UUID(), outcome: .cancelled)
        XCTAssertTrue(transport.addedNotifications.isEmpty)

        await service.postCompletion(id: UUID(), outcome: .completed)
        await service.postCompletion(id: UUID(), outcome: .completedWithWarnings)
        XCTAssertEqual(transport.addedNotifications.map(\.title), [
            "Analyse afgerond", "Analyse afgerond met aandachtspunten"
        ])
        XCTAssertEqual(transport.addedNotifications.map(\.body), [
            "De analyse is klaar. Bekijk de resultaten in CommissieWijzer en controleer ze aan de bron.",
            "De analyse is afgerond met aandachtspunten. Bekijk de meldingen en controleer de resultaten in CommissieWijzer."
        ])
        XCTAssertTrue(transport.addedNotifications.allSatisfy { $0.identifier.hasPrefix("analysis-completion-") })
    }

    func testSameOperationUUIDIsPostedOnlyOnce() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = FakeNotificationTransport(status: .authorized, alertsAllowed: true)
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)
        await service.refreshAuthorization()
        let operationID = UUID()

        await service.postCompletion(id: operationID, outcome: .completed)
        await service.postCompletion(id: operationID, outcome: .completed)

        XCTAssertEqual(transport.addedNotifications.count, 1)
    }

    func testEnglishNotificationCopyUsesInjectedInterfaceLanguage() async throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("en", forKey: "uiLanguage")
        let transport = FakeNotificationTransport(status: .authorized, alertsAllowed: true)
        let service = AnalysisCompletionNotifications(defaults: defaults, transport: transport)
        await service.refreshAuthorization()

        await service.postCompletion(id: UUID(), outcome: .completed)
        await service.postCompletion(id: UUID(), outcome: .completedWithWarnings)

        XCTAssertEqual(transport.addedNotifications.map(\.title), [
            "Analysis complete", "Analysis complete with items to review"
        ])
        XCTAssertEqual(transport.addedNotifications.map(\.body), [
            "The analysis is complete. Review the results in CommissieWijzer and check them against the source.",
            "The analysis is complete with items to review. Review the notices and check the results in CommissieWijzer."
        ])
    }

    func testDeniedOrAlertsDisabledNeverAddsNotification() async throws {
        for state in [
            FakeNotificationTransport(status: .denied, alertsAllowed: false),
            FakeNotificationTransport(status: .authorized, alertsAllowed: false)
        ] {
            let (defaults, suite) = makeDefaults()
            defer { defaults.removePersistentDomain(forName: suite) }
            let service = AnalysisCompletionNotifications(defaults: defaults, transport: state)
            await service.refreshAuthorization()
            await service.postCompletion(id: UUID(), outcome: .completed)
            XCTAssertTrue(state.addedNotifications.isEmpty)
        }
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "AnalysisCompletionNotificationsTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<2_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for the notification test transport.")
    }
}

@MainActor
private final class FakeNotificationTransport: AnalysisNotificationTransport {
    struct AddedNotification {
        let identifier: String
        let title: String
        let body: String
    }

    private(set) var status: UNAuthorizationStatus
    private(set) var alertsAllowed: Bool
    private(set) var authorizationRequestCount = 0
    private(set) var addStartedCount = 0
    private(set) var addedNotifications: [AddedNotification] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var removedPrefixes: [String] = []
    var holdAuthorization = true
    var holdAdds = false
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var addContinuation: CheckedContinuation<Void, Never>?

    init(status: UNAuthorizationStatus = .notDetermined, alertsAllowed: Bool = false) {
        self.status = status
        self.alertsAllowed = alertsAllowed
    }

    func authorizationState() async -> (status: UNAuthorizationStatus, alertsAllowed: Bool) {
        (status, alertsAllowed)
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        guard holdAuthorization else {
            status = .authorized
            alertsAllowed = true
            return true
        }
        return await withCheckedContinuation { authorizationContinuation = $0 }
    }

    func add(identifier: String, title: String, body: String) async throws {
        addStartedCount += 1
        addedNotifications.append(AddedNotification(identifier: identifier, title: title, body: body))
        if holdAdds { await withCheckedContinuation { addContinuation = $0 } }
    }

    func remove(identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllPending(withPrefix prefix: String) {
        removedPrefixes.append(prefix)
    }

    func installForegroundPresentation() {}

    func finishAuthorizationRequest(allowed: Bool) {
        status = allowed ? .authorized : .denied
        alertsAllowed = allowed
        authorizationContinuation?.resume(returning: allowed)
        authorizationContinuation = nil
    }

    func finishAdd() {
        addContinuation?.resume()
        addContinuation = nil
    }
}
