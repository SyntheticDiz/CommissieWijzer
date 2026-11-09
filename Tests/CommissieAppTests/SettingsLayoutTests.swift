import SwiftUI
import UserNotifications
import XCTest
@testable import CommissieWijzer

#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class SettingsLayoutTests: XCTestCase {
    func testSettingsRenderEverySectionWithSidebarAndInCompactLayout() async throws {
        let suite = "SettingsLayoutTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("nl", forKey: "uiLanguage")
        defaults.set("dark", forKey: "appearance")
        defaults.set("apple", forKey: "localAIProvider")
        defaults.set("/Voorbeeld/Exports", forKey: "exportFolder")

        let cloud = CloudSyncController(defaults: defaults, committeeLibrary: CommitteeLibrary(defaults: defaults)) {
            XCTFail("Rendering settings must not initialize an iCloud transport.")
            throw CloudSyncError.unavailable
        }
        let notifications = AnalysisCompletionNotifications(defaults: defaults, transport: RenderOnlyNotifications())
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let programURL = directory.appendingPathComponent("sample-program.json")
        try PartyProgram(name: "Voorbeeldprogramma", pages: ["Fictieve tekst"], pdf: Data()).save(to: programURL)

        #if os(iOS)
        let wideWidth: CGFloat = 900
        #else
        let wideWidth: CGFloat = 820
        #endif
        let sections = SettingsSection.allCases
        let layouts: [(name: String, width: CGFloat, text: DynamicTypeSize, sections: [SettingsSection?])] = [
            ("sidebar", wideWidth, .large, sections.map(Optional.some)),
            ("compact", 380, .large, [nil] + sections.map(Optional.some)),
            ("compact-large-text", 380, .accessibility3, [nil] + sections.map(Optional.some))
        ]
        let output = try renderDirectory()
        for layout in layouts {
            let size = CGSize(width: layout.width, height: 700)
            var captures = Set<Data>()
            for section in layout.sections {
                let view = AppSettingsView(initialSection: section, completionNotifications: notifications,
                                           cloudSync: cloud, refreshOnAppear: false, partyProgramURL: programURL)
                    .defaultAppStorage(defaults)
                    .environment(\.dynamicTypeSize, layout.text)
                    .frame(width: size.width, height: size.height)
                #if os(iOS)
                let data = try await renderOnIPad(view, size: size)
                #else
                let data = try renderOnMac(view, size: size)
                #endif

                let name = "settings-\(layout.name)-\(section?.rawValue ?? "categories")"
                XCTAssertGreaterThan(data.count, 1_000, "\(name) should render at \(size.width) points.")
                XCTAssertTrue(captures.insert(data).inserted, "\(name) should differ from the other rendered panes.")
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = name
                attachment.lifetime = .keepAlways
                add(attachment)
                if let output {
                    try data.write(to: output.appendingPathComponent("\(name).png"))
                }
            }
        }
        XCTAssertFalse(cloud.enabled)
        XCTAssertEqual(defaults.string(forKey: "localAIProvider"), "apple")
        XCTAssertEqual(defaults.string(forKey: "exportFolder"), "/Voorbeeld/Exports")
    }

    private func renderDirectory() throws -> URL? {
        let output: URL?
        if let path = ProcessInfo.processInfo.environment["CW_SETTINGS_UI_RENDER_DIR"] {
            output = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            #if os(iOS)
            output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("LayoutVerification", isDirectory: true)
            #else
            output = nil
            #endif
        }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        return output
    }

    #if os(iOS)
    private func renderOnIPad(_ view: some View, size: CGSize) async throws -> Data {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
        let original = window.rootViewController
        defer { window.rootViewController = original }
        let hosting = UIHostingController(rootView: view)
        hosting.overrideUserInterfaceStyle = .dark
        let container = UIViewController()
        window.rootViewController = container
        container.addChild(hosting)
        container.view.addSubview(hosting.view)
        hosting.didMove(toParent: container)
        defer {
            hosting.willMove(toParent: nil)
            hosting.view.removeFromSuperview()
            hosting.removeFromParent()
        }
        hosting.view.frame = CGRect(origin: .zero, size: size)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(250))
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.layoutIfNeeded()
        XCTAssertEqual(hosting.view.bounds.size, size)
        let image = UIGraphicsImageRenderer(bounds: hosting.view.bounds).image { _ in
            XCTAssertTrue(hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true))
        }
        return try XCTUnwrap(image.pngData())
    }
    #else
    private func renderOnMac(_ view: some View, size: CGSize) throws -> Data {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = hosting
        window.display()
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(hosting.bounds.size, size)
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
    #endif
}

@MainActor
private final class RenderOnlyNotifications: AnalysisNotificationTransport {
    func authorizationState() async -> (status: UNAuthorizationStatus, alertsAllowed: Bool) {
        XCTFail("Rendering settings must not contact system notification services.")
        return (.notDetermined, false)
    }

    func requestAuthorization() async throws -> Bool {
        XCTFail("Rendering settings must not request permission.")
        return false
    }

    func add(identifier: String, title: String, body: String) async throws {
        XCTFail("Rendering settings must not schedule notifications.")
    }

    func remove(identifiers: [String]) {}
    func removeAllPending(withPrefix prefix: String) {}
    func installForegroundPresentation() {}
}
