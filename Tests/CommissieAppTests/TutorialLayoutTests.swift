import SwiftUI
import XCTest
@testable import CommissieWijzer

#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class TutorialLayoutTests: XCTestCase {
    func testTourRendersEveryStepWithStaticPlayback() async throws {
        let size = CGSize(width: 900, height: 640)
        var captures = Set<Data>()
        for step in 0..<13 {
            let data = try await render(TutorialView(initialStep: step, staticPreview: true), size: size)
            XCTAssertTrue(captures.insert(data).inserted, "Step \(step + 1) should have its own rendered scene.")
            try attach(data, named: "tutorial-wide-\(step + 1)")
        }
    }

    func testWelcomeAndSettingsRoutesRenderAtRepresentativePhases() async throws {
        #if os(iOS)
        let width: CGFloat = 365
        #else
        let width: CGFloat = 492
        #endif
        let size = CGSize(width: width, height: 382)
        let frames = [(0, 0), (1, 1), (2, 1), (3, 0), (3, 2), (12, 0), (12, 1), (12, 2)]
        var captures = Set<Data>()
        for (step, phase) in frames {
            let preview = TutorialActualPreview(step: step, phase: phase,
                                                playbackStarted: .distantPast, reduceMotion: true)
            let data = try await render(preview, size: size)
            XCTAssertTrue(captures.insert(data).inserted, "Step \(step + 1) phase \(phase) should have its own scene.")
            try attach(data, named: "tutorial-preview-\(step + 1)-phase-\(phase)")
        }
    }

    #if os(iOS)
    func testCompactTourRendersPaneSwitcherAndLargeText() async throws {
        let size = CGSize(width: 380, height: 700)
        let source = TutorialView(initialStep: 6, staticPreview: true)
        let sourceData = try await render(source, size: size)
        try attach(sourceData, named: "tutorial-compact-source")

        let largeText = TutorialView(initialStep: 1, staticPreview: true)
            .environment(\.dynamicTypeSize, .accessibility3)
        let largeTextData = try await render(largeText, size: size)
        try attach(largeTextData, named: "tutorial-compact-large-text")
        XCTAssertNotEqual(sourceData, largeTextData)
    }
    #endif

    private func attach(_ data: Data, named name: String) throws {
        XCTAssertGreaterThan(data.count, 1_000, "\(name) should render a native preview.")
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let output = renderDirectory {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try data.write(to: output.appendingPathComponent("\(name).png"))
        }
    }

    private var renderDirectory: URL? {
        if let path = ProcessInfo.processInfo.environment["CW_TUTORIAL_UI_RENDER_DIR"] {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        #if os(iOS)
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LayoutVerification", isDirectory: true)
        #else
        return nil
        #endif
    }

    private func render(_ view: some View, size: CGSize) async throws -> Data {
        let sizedView = view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
        #if os(iOS)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
        let original = window.rootViewController
        defer { window.rootViewController = original }
        let hosting = UIHostingController(rootView: sizedView)
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
        #else
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: sizedView)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = hosting
        window.display()
        try await Task.sleep(for: .milliseconds(100))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(hosting.bounds.size, size)
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        #endif
    }
}
