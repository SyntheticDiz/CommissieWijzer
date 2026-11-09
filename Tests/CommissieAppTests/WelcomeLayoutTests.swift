import XCTest
import SwiftUI
@testable import CommissieWijzer
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class WelcomeLayoutTests: XCTestCase {
    func testWelcomeRendersNarrowAndWideWithCollapsedAndExpandedRecentWork() async throws {
        let suite = "WelcomeLayoutTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("dark", forKey: "appearance")
        let cloud = CloudSyncController(defaults: defaults) {
            XCTFail("The welcome render must not activate iCloud.")
            throw CloudSyncError.unavailable
        }
        let recent = RecentWorkspaceDocuments(defaults: defaults)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["Commissiestuk openbare ruimte", "Werkdocument begroting en meerjarenraming"] {
            let url = directory.appendingPathComponent(name).appendingPathExtension("spdfwork")
            try Data().write(to: url)
            try recent.record(url)
        }
        XCTAssertEqual(recent.entries.count, 2)

        #if os(macOS)
        // A SwiftPM test executable has no app bundle icon.
        let application = NSApplication.shared
        let originalIcon = application.applicationIconImage
        defer { application.applicationIconImage = originalIcon }
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        application.applicationIconImage = try XCTUnwrap(
            NSImage(contentsOf: project.appendingPathComponent("Assets/CommissieWijzer.png"))
        )
        #endif

        let scenarios: [(name: String, width: CGFloat, text: DynamicTypeSize, expanded: Bool, provider: String)] = [
            ("narrow-320-collapsed", 320, .large, false, "apple"),
            ("wide-880-collapsed", 880, .large, false, "chatgpt"),
            ("wide-880-expanded", 880, .large, true, "chatgpt"),
            ("narrow-400-large-text", 400, .accessibility3, true, "apple"),
        ]
        let output = try renderDirectory()
        var wideCollapsed: Data?
        for scenario in scenarios {
            defaults.set(scenario.provider, forKey: "localAIProvider")
            let size = CGSize(width: scenario.width, height: 900)
            let view = NavigationStack {
                SimpleView(cloudSync: cloud, recentDocuments: recent, recentInitiallyExpanded: scenario.expanded)
            }
            .defaultAppStorage(defaults)
            .environment(\.dynamicTypeSize, scenario.text)
            .frame(width: size.width, height: size.height)
            #if os(iOS)
            let data = try await renderOnIPad(view, size: size)
            #else
            let data = try renderOnMac(view, size: size)
            #endif
            XCTAssertGreaterThan(data.count, 1_000)
            if scenario.name == "wide-880-collapsed" { wideCollapsed = data }
            if scenario.name == "wide-880-expanded" {
                XCTAssertNotEqual(data, try XCTUnwrap(wideCollapsed), "Expanding recent work changes the rendered welcome.")
            }
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "Welcome \(scenario.name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if let output { try data.write(to: output.appendingPathComponent("welcome-\(scenario.name).png")) }
        }
        XCTAssertFalse(cloud.enabled)
    }

    func testProcessingActionsRenderAtNarrowAndWideWidths() async throws {
        let output = try renderDirectory(environmentKey: "CW_PROCESSING_UI_RENDER_DIR")
        let scenarios: [(name: String, width: CGFloat, text: DynamicTypeSize, failed: Bool)] = [
            ("wide-460", 460, .large, false),
            ("narrow-280", 280, .large, false),
            ("narrow-280-large-text", 280, .accessibility3, false),
            ("error-460", 460, .large, true),
        ]
        let noAction: () -> Void = {}
        for scenario in scenarios {
            let size = CGSize(width: scenario.width, height: scenario.text.isAccessibilitySize ? 600 : 260)
            let view = ProcessingActions(
                returnTitle: scenario.failed ? "Terug naar importeren" : "Stop en terug naar importeren",
                onReturnToImport: noAction,
                onOpenResults: noAction,
                onSwitchModel: scenario.failed ? nil : noAction
            )
            .environment(\.dynamicTypeSize, scenario.text)
            .frame(width: size.width, height: size.height)
            .background(AppTheme.background)
            .preferredColorScheme(.dark)
            #if os(iOS)
            let data = try await renderOnIPad(view, size: size)
            #else
            let data = try renderOnMac(view, size: size)
            #endif
            XCTAssertGreaterThan(data.count, 1_000)
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "Processing actions \(scenario.name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if let output { try data.write(to: output.appendingPathComponent("processing-actions-\(scenario.name).png")) }
        }
    }

    private func renderDirectory(environmentKey: String = "CW_WELCOME_UI_RENDER_DIR") throws -> URL? {
        let environmentPath = ProcessInfo.processInfo.environment[environmentKey]
        let output: URL?
        if let environmentPath {
            output = URL(fileURLWithPath: environmentPath, isDirectory: true)
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
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
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
