#if os(iOS)
import XCTest
import SwiftUI
import UIKit
import PDFKit
@testable import CommissieWijzer

/// Captures real restored workspaces for App Store review. The fixture contains
/// only the fictional Voorbeeldstad library proposal and its selectable PDF.
@MainActor
final class IPadStoreScreenshotTests: XCTestCase {
    func testCapture13InchDocumentPoints() async throws {
        try await capture(name: "01-documentpunten", section: "Punten", pointsMode: "featured")
    }

    func testCapture13InchAllDocumentPoints() async throws {
        try await capture(name: "02-alle-documentpunten", section: "Punten", pointsMode: "all")
    }

    func testCapture13InchMySelection() async throws {
        try await capture(name: "04-mijn-selectie", section: "Mijn selectie", pointsMode: "mine")
    }

    func testCapture13InchLocalSearch() async throws {
        try await capture(name: "03-lokaal-zoeken", section: "Zoeken", pointsMode: "featured", search: "onderhoud")
    }

    private func capture(name: String, section: String, pointsMode: String, search: String = "") async throws {
        guard ProcessInfo.processInfo.environment["CW_CAPTURE_STORE_SCREENSHOTS"] == "1" else {
            throw XCTSkip("Set CW_CAPTURE_STORE_SCREENSHOTS=1 to capture App Store screenshots.")
        }
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "ipad-store-demo", withExtension: "spdfwork"))
        let archive = try WorkspaceArchive.read(fixture)
        XCTAssertGreaterThan(archive.pdf.count, 0, "The screenshot fixture must retain its original PDF")
        XCTAssertEqual(PDFDocument(data: archive.pdf)?.pageCount, archive.pages.count)
        XCTAssertTrue(archive.pages.joined(separator: " ").contains("Voorbeeldstad"), "Fixture must remain fictional")

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
        let originalController = window.rootViewController
        let defaults = UserDefaults.standard
        let previousPDFChoice = defaults.object(forKey: "showPDFPane")
        defer {
            window.rootViewController = originalController
            if let previousPDFChoice { defaults.set(previousPDFChoice, forKey: "showPDFPane") }
            else { defaults.removeObject(forKey: "showPDFPane") }
        }

        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppStoreScreenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        // Use the simulator's actual full-window size at native resolution.
        var screenshotArchive = archive
        var viewState = screenshotArchive.viewState ?? WorkspaceViewState()
        viewState.section = section
        viewState.pointsMode = pointsMode
        viewState.pdfVisible = true
        viewState.pointsExpanded = true
        viewState.search = search
        viewState.openGroups = ["Overige onderwerpen"]
        screenshotArchive.viewState = viewState

        let workspace = SimpleWorkspace()
        let controller = UIHostingController(rootView: NavigationStack {
            SimpleView(workspace: workspace)
        }
        .appPresentationContextHost()
        .preferredColorScheme(.dark))
        controller.overrideUserInterfaceStyle = .dark
        window.rootViewController = controller
        window.makeKeyAndVisible()

        // Mount before restore so SimpleView observes the documentID change and
        // applies the saved section, search query and PDF visibility.
        try await Task.sleep(nanoseconds: 350_000_000)
        try workspace.restore(screenshotArchive, persist: false)
        try await Task.sleep(nanoseconds: 1_500_000_000)

        XCTAssertTrue(workspace.presentationContext?.foregroundWindow === window)
        XCTAssertEqual(controller.traitCollection.userInterfaceStyle, .dark)
        XCTAssertEqual(controller.view.bounds.size, window.bounds.size, "Capture must use the actual full-window view")
        XCTAssertFalse(workspace.showsWelcome, "Capture should show the restored workspace, not onboarding")
        XCTAssertTrue(defaults.bool(forKey: "showPDFPane"), "Restored workspace should keep its PDF pane visible")
        let pdfViews = descendants(of: controller.view).compactMap { $0 as? PDFView }
        XCTAssertTrue(pdfViews.contains { $0.bounds.width >= 300 && $0.document?.pageCount == archive.pages.count },
                      "Capture should contain the restored original PDF beside the workbench")

        // Keep the actual simulator display stable long enough for simctl to
        // capture the native app window during a manual Store-image run.
        try await Task.sleep(nanoseconds: 10_000_000_000)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds, format: format).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let pixelSize = "\(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))"
        XCTAssertTrue(["2732x2048", "2048x2732", "2752x2064", "2064x2752"].contains(pixelSize),
                      "Unexpected native 13-inch iPad screenshot dimensions: \(pixelSize)")
        let imageURL = output.appendingPathComponent("CommissieWijzer-iPad-13-\(name).png")
        try XCTUnwrap(image.pngData()).write(to: imageURL, options: .atomic)

        let attachment = XCTAttachment(image: image)
        attachment.name = "App Store iPad 13 inch - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
#endif
