import Combine
import Foundation
import UserNotifications

enum AnalysisCompletionOutcome: Sendable, Equatable {
    case completed
    case completedWithWarnings
    case failed
    case cancelled

    fileprivate func notificationCopy(language: String) -> (title: String, body: String)? {
        switch self {
        case .completed:
            (UIStrings.text("Analyse afgerond", language: language),
             UIStrings.text("De analyse is klaar. Bekijk de resultaten in CommissieWijzer en controleer ze aan de bron.", language: language))
        case .completedWithWarnings:
            (UIStrings.text("Analyse afgerond met aandachtspunten", language: language),
             UIStrings.text("De analyse is afgerond met aandachtspunten. Bekijk de meldingen en controleer de resultaten in CommissieWijzer.", language: language))
        case .failed, .cancelled: nil
        }
    }
}

@MainActor
protocol AnalysisNotificationTransport: AnyObject {
    func authorizationState() async -> (status: UNAuthorizationStatus, alertsAllowed: Bool)
    func requestAuthorization() async throws -> Bool
    func add(identifier: String, title: String, body: String) async throws
    func remove(identifiers: [String])
    func removeAllPending(withPrefix prefix: String)
    func installForegroundPresentation()
}

@MainActor
final class AnalysisCompletionNotifications: ObservableObject {
    static let shared = AnalysisCompletionNotifications()

    nonisolated static let enabledDefaultsKey = "analysisCompletionNotificationsEnabled"
    private static let identifierPrefix = "analysis-completion-"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var canDeliverNotifications = false
    @Published private(set) var statusMessage: String?

    private let defaults: UserDefaults
    private let transport: any AnalysisNotificationTransport
    private var authorizationFlight: Task<Bool, Never>?
    private var inFlightIDs: Set<UUID> = []
    private var postedIDs: Set<UUID> = []
    private var invalidatedIDs: Set<UUID> = []

    init(defaults: UserDefaults = .standard,
         transport: (any AnalysisNotificationTransport)? = nil) {
        self.defaults = defaults
        self.transport = transport ?? SystemAnalysisNotificationTransport()
        if defaults.object(forKey: Self.enabledDefaultsKey) == nil {
            defaults.set(true, forKey: Self.enabledDefaultsKey)
            isEnabled = true
        } else {
            isEnabled = defaults.bool(forKey: Self.enabledDefaultsKey)
        }
    }

    /// Ask the operating system only after the user enables notifications or
    /// starts an actual analysis. Callers never wait for the permission sheet.
    func prepareForAnalysis() {
        guard isEnabled else { return }
        Task { [weak self] in _ = await self?.requestAuthorizationIfNeeded() }
    }

    func setEnabled(_ enabled: Bool) async {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledDefaultsKey)

        if enabled {
            _ = await requestAuthorizationIfNeeded()
        } else {
            transport.removeAllPending(withPrefix: Self.identifierPrefix)
            await refreshAuthorization()
        }
    }

    func refreshAuthorization() async {
        let state = await transport.authorizationState()
        apply(state)
    }

    func installDelegate() {
        transport.installForegroundPresentation()
    }

    func postCompletion(id: UUID, outcome: AnalysisCompletionOutcome) async {
        let language = defaults.string(forKey: "uiLanguage") ?? "nl"
        guard let copy = outcome.notificationCopy(language: language),
              !Task.isCancelled,
              isEnabled, !invalidatedIDs.contains(id),
              !postedIDs.contains(id), inFlightIDs.insert(id).inserted else { return }
        defer { inFlightIDs.remove(id) }

        let authorized = await requestAuthorizationIfNeeded()
        guard !Task.isCancelled, isEnabled, authorized, !invalidatedIDs.contains(id) else { return }

        let identifier = Self.identifierPrefix + id.uuidString
        do {
            guard !Task.isCancelled, isEnabled, !invalidatedIDs.contains(id), canDeliverNotifications else { return }
            try await transport.add(identifier: identifier, title: copy.title, body: copy.body)
            let finalState = await transport.authorizationState()
            apply(finalState)
            guard !Task.isCancelled, isEnabled, !invalidatedIDs.contains(id),
                  finalState.status == .authorized, finalState.alertsAllowed else {
                transport.remove(identifiers: [identifier])
                return
            }
            postedIDs.insert(id)

            // A user may switch notifications off while the OS add call is
            // suspended. Remove any late arrival before this method returns.
        } catch {
            statusMessage = UIStrings.text("De melding kon niet worden klaargezet.")
        }
    }

    /// Invalidates a run even if its permission request or notification add is
    /// still suspended, and removes any notification already scheduled for it.
    func cancel(id: UUID) {
        invalidatedIDs.insert(id)
        postedIDs.remove(id)
        transport.remove(identifiers: [Self.identifierPrefix + id.uuidString])
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        if let authorizationFlight {
            return await authorizationFlight.value && isEnabled && canDeliverNotifications
        }

        let transport = self.transport
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            let currentState = await transport.authorizationState()
            self.apply(currentState)
            guard self.isEnabled else { return false }
            var allowed = currentState.status == .authorized && currentState.alertsAllowed
            if currentState.status == .notDetermined {
                do { allowed = try await transport.requestAuthorization() }
                catch { allowed = false }
            }
            let updatedState = await transport.authorizationState()
            self.apply(updatedState)
            guard self.isEnabled else { return false }
            let ready = allowed && updatedState.status == .authorized && updatedState.alertsAllowed
            if ready { self.statusMessage = UIStrings.text("Meldingen zijn ingeschakeld") }
            return ready
        }
        authorizationFlight = task
        let result = await task.value
        authorizationFlight = nil
        return result && isEnabled && canDeliverNotifications
    }

    private func apply(_ state: (status: UNAuthorizationStatus, alertsAllowed: Bool)) {
        authorizationStatus = state.status
        canDeliverNotifications = state.status == .authorized && state.alertsAllowed
        if !isEnabled {
            statusMessage = UIStrings.text("Meldingen zijn uitgeschakeld")
        } else if canDeliverNotifications {
            statusMessage = UIStrings.text("Meldingen zijn ingeschakeld")
        } else {
            switch state.status {
            case .notDetermined:
                statusMessage = UIStrings.text("Sta meldingen toe")
            case .denied:
                statusMessage = UIStrings.text("Sta meldingen toe in Systeeminstellingen")
            case .authorized, .provisional, .ephemeral:
                statusMessage = UIStrings.text("Sta meldingen toe in Systeeminstellingen")
            @unknown default:
                statusMessage = UIStrings.text("De meldingsstatus kon niet worden vastgesteld.")
            }
        }
    }
}

@MainActor
private final class SystemAnalysisNotificationTransport: AnalysisNotificationTransport {
    private let center = UNUserNotificationCenter.current()
    private let foregroundDelegate = AnalysisNotificationForegroundDelegate()

    func authorizationState() async -> (status: UNAuthorizationStatus, alertsAllowed: Bool) {
        let settings = await withCheckedContinuation { continuation in
            center.getNotificationSettings { continuation.resume(returning: $0) }
        }
        return (settings.authorizationStatus, settings.alertSetting == .enabled)
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(identifier: String, title: String, body: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removeAllPending(withPrefix prefix: String) {
        center.getPendingNotificationRequests { [weak self] requests in
            let identifiers = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !identifiers.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }
    }

    func installForegroundPresentation() {
        center.delegate = foregroundDelegate
    }
}

private final class AnalysisNotificationForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
