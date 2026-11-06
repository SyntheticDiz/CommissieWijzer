import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Notification.Name {
    static let appOpenPDF = Notification.Name("CommissieWijzerOpenPDF")
    static let appFind = Notification.Name("CommissieWijzerFind")
    static let appRequestTermination = Notification.Name("CommissieWijzerRequestTermination")
    static let appRequestWindowClose = Notification.Name("CommissieWijzerRequestWindowClose")
}

#if os(macOS)
@MainActor enum WorkspaceWindowRegistry {
    private final class WeakWorkspace {
        weak var value: SimpleWorkspace?
        init(_ value: SimpleWorkspace) { self.value = value }
    }
    private static var workspaces: [ObjectIdentifier: WeakWorkspace] = [:]
    private static var authorizedTerminationRevisions: [ObjectIdentifier: UUID] = [:]
    static func register(_ workspace: SimpleWorkspace) { workspaces[ObjectIdentifier(workspace)] = WeakWorkspace(workspace) }
    static func unregister(_ workspace: SimpleWorkspace) {
        let id = ObjectIdentifier(workspace)
        workspaces.removeValue(forKey: id)
        authorizedTerminationRevisions.removeValue(forKey: id)
    }
    static var hasUnsavedChanges: Bool {
        workspaces = workspaces.filter { $0.value.value != nil }
        return workspaces.contains { id, item in
            guard let workspace = item.value, workspace.document != nil, workspace.hasUnsavedChanges else { return false }
            return authorizedTerminationRevisions[id] != workspace.revisionToken
        }
    }
    static func requestNextDirtyWorkspace() -> Bool {
        workspaces = workspaces.filter { $0.value.value != nil }
        guard let match = workspaces.first(where: { id, item in
            guard let workspace = item.value, workspace.document != nil, workspace.hasUnsavedChanges else { return false }
            return authorizedTerminationRevisions[id] != workspace.revisionToken
        }), let workspace = match.value.value else { return false }
        NotificationCenter.default.post(name: .appRequestTermination, object: ObjectIdentifier(workspace))
        return true
    }
    static func autosaveOpenedWorkdocuments() async -> [String] {
        workspaces = workspaces.filter { $0.value.value != nil }
        let eligible = workspaces.values.compactMap(\.value).filter { $0.document != nil && $0.hasUnsavedChanges }
        var failures: [String] = []
        for workspace in eligible {
            do { try await workspace.persistCloudWorkIfNeeded(using: .shared) }
            catch {
                let name = workspace.document?.name ?? "Werkdocument"
                failures.append("iCloud · \(name): \(error.localizedDescription)")
            }
            guard workspace.document != nil, workspace.hasUnsavedChanges, workspace.isOpenedWorkdocument else { continue }
            do { try await workspace.autosaveOpenedWorkdocument() }
            catch {
                let name = workspace.openedWorkdocumentURL?.lastPathComponent ?? "Werkdocument"
                failures.append("\(name): \(error.localizedDescription)")
            }
        }
        return failures
    }
    static func authorizeTerminationRevision(for workspace: SimpleWorkspace) {
        authorizedTerminationRevisions[ObjectIdentifier(workspace)] = workspace.revisionToken
    }
    static func cancelTerminationSequence() { authorizedTerminationRevisions.removeAll() }
}

@MainActor final class SavedWorkTerminationCoordinator {
    private(set) var isWaitingForDrain = false

    func begin(
        drain: @escaping () async -> [String],
        autosaveOpenedWorkdocuments: @escaping () async -> [String] = { [] },
        hasUnsavedChanges: @escaping () -> Bool,
        requestNextDirtyWorkspace: @escaping () -> Void,
        presentSaveFailures: @escaping ([String]) -> Void,
        reply: @escaping (Bool) -> Void
    ) -> NSApplication.TerminateReply {
        guard !isWaitingForDrain else { return .terminateLater }
        isWaitingForDrain = true
        Task { @MainActor in
            var failures: [String] = []
            while true {
                while true {
                    let generation = SavedWork.scheduledGeneration
                    failures.append(contentsOf: await drain())
                    if SavedWork.scheduledGeneration == generation { break }
                }
                guard failures.isEmpty else { break }
                let generationBeforeAutosave = SavedWork.scheduledGeneration
                let autosaveFailures = await autosaveOpenedWorkdocuments()
                failures.append(contentsOf: autosaveFailures)
                guard autosaveFailures.isEmpty,
                      SavedWork.scheduledGeneration != generationBeforeAutosave else { break }
            }
            guard failures.isEmpty else {
                presentSaveFailures(failures)
                isWaitingForDrain = false
                reply(false)
                return
            }
            guard !hasUnsavedChanges() else {
                requestNextDirtyWorkspace()
                isWaitingForDrain = false
                reply(false)
                return
            }
            isWaitingForDrain = false
            reply(true)
        }
        return .terminateLater
    }
}

@MainActor final class CommissieWijzerAppDelegate: NSObject, NSApplicationDelegate {
    private let terminationCoordinator: SavedWorkTerminationCoordinator
    private let replyToTermination: (NSApplication, Bool) -> Void
    private let presentTerminationFailures: ([String]) -> Void

    override init() {
        terminationCoordinator = SavedWorkTerminationCoordinator()
        replyToTermination = { application, shouldTerminate in
            if shouldTerminate { WorkspaceWindowRegistry.cancelTerminationSequence() }
            application.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        presentTerminationFailures = { failures in
            let alert = NSAlert()
            alert.messageText = UIStrings.text("Niet-bewaarde wijzigingen")
            alert.informativeText = failures.joined(separator: "\n")
            alert.alertStyle = .warning
            alert.addButton(withTitle: UIStrings.text("OK"))
            alert.runModal()
        }
        super.init()
    }

    init(
        terminationCoordinator: SavedWorkTerminationCoordinator,
        replyToTermination: @escaping (NSApplication, Bool) -> Void,
        presentTerminationFailures: @escaping ([String]) -> Void
    ) {
        self.terminationCoordinator = terminationCoordinator
        self.replyToTermination = replyToTermination
        self.presentTerminationFailures = presentTerminationFailures
        super.init()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationCoordinator.isWaitingForDrain { return .terminateLater }
        return terminationCoordinator.begin(
            drain: { await SavedWork.drain() },
            autosaveOpenedWorkdocuments: { await WorkspaceWindowRegistry.autosaveOpenedWorkdocuments() },
            hasUnsavedChanges: { WorkspaceWindowRegistry.hasUnsavedChanges },
            requestNextDirtyWorkspace: { _ = WorkspaceWindowRegistry.requestNextDirtyWorkspace() },
            presentSaveFailures: presentTerminationFailures,
            reply: { shouldTerminate in self.replyToTermination(sender, shouldTerminate) }
        )
    }
}

#endif

#if os(macOS)
@main
struct CommissieWijzerApp: App {
    @NSApplicationDelegateAdaptor(CommissieWijzerAppDelegate.self) private var appDelegate
    init() {
        ForkSetup.migrate()
        AppleAISettings.migrate()
        AnalysisCompletionNotifications.shared.installDelegate()
    }
    var body: some Scene {
        WindowGroup("CommissieWijzer") {
            SimpleView().frame(minWidth: 900, minHeight: 620).tint(AppTheme.accent)
                .buttonStyle(FocusSecondaryButtonStyle())
                .disclosureGroupStyle(FullRowDisclosureGroupStyle())
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }.windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(UIStrings.text("Open pdf…")) { NotificationCenter.default.post(name: .appOpenPDF, object: nil) }
                    .keyboardShortcut("o", modifiers: .command)
            }
            WorkspaceFileCommands()
            CommandGroup(after: .textEditing) {
                Button(UIStrings.text("Zoek in document")) { NotificationCenter.default.post(name: .appFind, object: nil) }
                    .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}
#else
@main
struct CommissieWijzerApp: App {
    init() {
        ForkSetup.migrate()
        AppleAISettings.migrate()
        AnalysisCompletionNotifications.shared.installDelegate()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SimpleView()
            }
                .appPresentationContextHost()
                .tint(AppTheme.accent)
                .buttonStyle(FocusSecondaryButtonStyle())
                .disclosureGroupStyle(FullRowDisclosureGroupStyle())
                .preferredColorScheme(.dark)
        }
    }
}
#endif

struct WorkspaceFileMenuActions {
    let canOpen: Bool
    let canSave: Bool
    let open: () -> Void
    let save: () -> Void
}

private struct WorkspaceFileMenuActionsKey: FocusedValueKey {
    typealias Value = WorkspaceFileMenuActions
}

extension FocusedValues {
    var appWorkspaceFileMenuActions: WorkspaceFileMenuActions? {
        get { self[WorkspaceFileMenuActionsKey.self] }
        set { self[WorkspaceFileMenuActionsKey.self] = newValue }
    }
}

#if os(macOS)
private struct WorkspaceFileCommands: Commands {
    @FocusedValue(\.appWorkspaceFileMenuActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            if let actions {
                Button(UIStrings.text("Werkdocument openen…")) { actions.open() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(!actions.canOpen)
                Button(UIStrings.text("Werkdocument bewaren…")) { actions.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!actions.canSave)
            }
        }
    }
}
#endif
