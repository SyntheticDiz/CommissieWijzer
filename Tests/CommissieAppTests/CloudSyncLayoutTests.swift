import XCTest
import SwiftUI
@testable import CommissieWijzer
#if os(iOS)
import UIKit
#else
import AppKit
#endif

private actor RenderOnlyCloudTransport: CloudSyncTransport {
    private(set) var calls = 0
    func accountIdentifier() async throws -> String { calls += 1; return "render-only" }
    func listDossiers() async throws -> [CloudRemoteDossier] { calls += 1; return [] }
    func fetchArchive(id: UUID) async throws -> CloudArchiveDownload { calls += 1; throw CloudSyncError.dossierMissing }
    func saveArchive(id: UUID, title: String, modifiedAt: Date, contentHash: String,
                     expectedRevision: String?, archive: Data) async throws -> CloudRemoteDossier {
        calls += 1; throw CloudSyncError.unavailable
    }
    func listCommitteeVersions() async throws -> [CloudRemoteCommitteeVersion] { calls += 1; return [] }
    func fetchCommittees(id: UUID) async throws -> CloudCommitteeDownload { calls += 1; throw CloudSyncError.dossierMissing }
    func saveCommittees(id: UUID, modifiedAt: Date, contentHash: String,
                        expectedRevision: String?, payload: Data) async throws -> CloudRemoteCommitteeVersion {
        calls += 1; throw CloudSyncError.unavailable
    }
    func callCount() -> Int { calls }
}

@MainActor
final class CloudSyncLayoutTests: XCTestCase {
    func testCloudSettingsAndLibraryFitNarrowAndWideWindowsWithLargeText() async throws {
        let suite = "CloudSyncLayoutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let transport = RenderOnlyCloudTransport()
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let controller = CloudSyncController(defaults: defaults) {
            CloudSyncStore(directory: cache, transport: transport)
        }
        XCTAssertFalse(controller.enabled)
        let views: [(String, AnyView)] = [
            ("settings", AnyView(ScrollView { CloudSyncSettingsView(cloud: controller).padding(16) })),
            ("library", AnyView(CloudLibraryView(cloud: controller, open: { _, _ in })))
        ]
        let sizes: [(String, CGSize)] = [("narrow-400", CGSize(width: 400, height: 760)),
                                        ("wide-760", CGSize(width: 760, height: 760))]
        let outputPath = ProcessInfo.processInfo.environment["CW_CLOUD_UI_RENDER_DIR"]
        if let outputPath { try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true) }

        for (name, view) in views {
            for (sizeName, size) in sizes {
                let rendered = view.environment(\.dynamicTypeSize, .accessibility3)
                    .preferredColorScheme(.dark)
                    .frame(width: size.width, height: size.height)
                #if os(iOS)
                let image = try await renderOnIPad(rendered, size: size)
                let data = try XCTUnwrap(image.pngData())
                let attachment = XCTAttachment(image: image)
                attachment.name = "Cloud sync \(name) \(sizeName) · large text"
                attachment.lifetime = .keepAlways
                add(attachment)
                #else
                let data = try renderOnMac(rendered, size: size)
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = "Cloud sync \(name) \(sizeName) · large text"
                attachment.lifetime = .keepAlways
                add(attachment)
                #endif
                XCTAssertGreaterThan(data.count, 1_000, "The \(name) view should render at \(size.width) points.")
                if let outputPath {
                    try data.write(to: URL(fileURLWithPath: outputPath).appendingPathComponent("\(name)-\(sizeName).png"))
                }
            }
        }
        XCTAssertFalse(controller.enabled)
        let cloudCalls = await transport.callCount()
        XCTAssertEqual(cloudCalls, 0, "Rendering the views must not contact iCloud.")
    }

    #if os(iOS)
    private func renderOnIPad(_ view: some View, size: CGSize) async throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
        let original = window.rootViewController
        defer { window.rootViewController = original }
        let hosting = UIHostingController(rootView: view)
        let container = UIViewController()
        window.rootViewController = container
        container.addChild(hosting); container.view.addSubview(hosting.view); hosting.didMove(toParent: container)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        window.makeKeyAndVisible()
        try await Task.sleep(nanoseconds: 250_000_000)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.layoutIfNeeded()
        XCTAssertEqual(hosting.view.bounds.width, size.width)
        let image = UIGraphicsImageRenderer(bounds: hosting.view.bounds).image { _ in
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
        hosting.willMove(toParent: nil); hosting.view.removeFromSuperview(); hosting.removeFromParent()
        return image
    }
    #else
    private func renderOnMac(_ view: some View, size: CGSize) throws -> Data {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.display()
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        window.close()
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
    #endif
}
