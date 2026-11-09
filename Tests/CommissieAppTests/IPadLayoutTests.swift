#if os(iOS)
import XCTest
import SwiftUI
import UIKit
import PDFKit
@testable import CommissieWijzer

@MainActor
final class IPadLayoutTests: XCTestCase {
    func testUnattachedPresentationContextHasNoPresenter() {
        let context = AppPresentationContext()
        XCTAssertNil(context.foregroundWindow)
        XCTAssertNil(context.foregroundPresenter)
    }

    func testDarkWorkbenchInLandscapeAndPortrait() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mac-v1", withExtension: "spdfwork"))
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
            .appendingPathComponent("LayoutVerification", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, size, showPDF) in [("landscape", CGSize(width: 1210, height: 834), true),
                                       ("portrait", CGSize(width: 834, height: 1210), false)] {
            let workspace = SimpleWorkspace()
            try workspace.restore(WorkspaceArchive.read(fixture), persist: false)
            defaults.set(showPDF, forKey: "showPDFPane")
            let controller = UIHostingController(rootView: NavigationStack {
                SimpleView(workspace: workspace)
            }
            .appPresentationContextHost()
            .tint(AppTheme.accent)
            .buttonStyle(FocusSecondaryButtonStyle())
            .disclosureGroupStyle(FullRowDisclosureGroupStyle())
            .preferredColorScheme(.dark))
            controller.overrideUserInterfaceStyle = .dark
            // Exercise resizable iPad windows directly, independent of the
            // simulator's physical orientation and the test runner's scene policy.
            let container = UIViewController()
            window.rootViewController = container
            container.addChild(controller)
            container.view.addSubview(controller.view)
            controller.didMove(toParent: container)
            controller.view.autoresizingMask = []
            controller.view.frame = CGRect(origin: .zero, size: size)
            window.makeKeyAndVisible()
            try await Task.sleep(nanoseconds: 750_000_000)
            controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.layoutIfNeeded()
            XCTAssertTrue(workspace.presentationContext?.foregroundWindow === window,
                          "The workbench must receive the presentation context attached above NavigationStack")
            XCTAssertEqual(controller.traitCollection.userInterfaceStyle, .dark)
            XCTAssertGreaterThan(controller.view.bounds.width, 600)
            if name == "landscape" {
                XCTAssertGreaterThan(controller.view.bounds.width, controller.view.bounds.height)
                let pdfViews = descendants(of: controller.view).compactMap { $0 as? PDFView }
                XCTAssertTrue(pdfViews.contains { $0.bounds.width >= 300 }, "The original PDF must remain visible beside the workbench")
            } else {
                XCTAssertGreaterThan(controller.view.bounds.height, controller.view.bounds.width)
            }
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("ipad-\(name).png"))
            let attachment = XCTAttachment(image: image)
            attachment.name = "CommissieWijzer iPad \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testNarrowWorkbenchRendersBothPaneChoices() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mac-v1", withExtension: "spdfwork"))
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
            .appendingPathComponent("LayoutVerification", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        for (name, showPDF) in [("original-pdf", true), ("workbench", false)] {
            let workspace = SimpleWorkspace()
            try workspace.restore(WorkspaceArchive.read(fixture), persist: false)
            defaults.set(showPDF, forKey: "showPDFPane")
            let controller = UIHostingController(rootView: NavigationStack {
                SimpleView(workspace: workspace)
            }
            .appPresentationContextHost()
            .tint(AppTheme.accent)
            .buttonStyle(FocusSecondaryButtonStyle())
            .disclosureGroupStyle(FullRowDisclosureGroupStyle())
            .preferredColorScheme(.dark))
            controller.overrideUserInterfaceStyle = .dark
            let container = UIViewController()
            window.rootViewController = container
            container.addChild(controller)
            container.view.addSubview(controller.view)
            controller.didMove(toParent: container)
            controller.view.autoresizingMask = []
            controller.view.frame = CGRect(x: 0, y: 0, width: 834, height: 1210)
            window.makeKeyAndVisible()
            try await Task.sleep(nanoseconds: 750_000_000)
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()

            let pdfViews = descendants(of: controller.view).compactMap { $0 as? PDFView }
            if showPDF {
                XCTAssertTrue(pdfViews.contains { $0.bounds.width > 300 && $0.bounds.height > 300 },
                              "The original PDF must fill the narrow iPad pane when selected")
            } else {
                XCTAssertTrue(pdfViews.allSatisfy { $0.bounds.width < 10 || $0.bounds.height < 10 },
                              "The hidden PDF must not remain visible when the workbench is selected")
            }

            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("ipad-narrow-\(name).png"))
            let attachment = XCTAttachment(image: image)
            attachment.name = "CommissieWijzer narrow iPad \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            controller.willMove(toParent: nil)
            controller.view.removeFromSuperview()
            controller.removeFromParent()
        }
    }

    func testSettingsReadersFocusAndExportRenderInBothOrientations() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mac-v1", withExtension: "spdfwork"))
        let archive = try WorkspaceArchive.read(fixture)
        let sizes: [(String, CGSize)] = [("landscape", CGSize(width: 1210, height: 834)),
                                         ("portrait", CGSize(width: 834, height: 1210))]
        let point = Insight(title: "Fictief aandachtspunt", summary: "Een korte fictieve samenvatting.",
                            relevance: "relevant", question: "", quote: "De raad bespreekt het voorstel.", page: 1)
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LayoutVerification", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (viewName, view) in [
            ("settings", AnyView(AppSettingsView())),
            ("committees", AnyView(CommitteeManagerView())),
            ("committee-editor", AnyView(CommitteeDefinitionEditor(title: "Commissie aanpassen",
                definition: CommitteeDefinition(id: "layout-fixture", revision: "1",
                    name: "Samenleving en gemeentelijke voorzieningen",
                    topics: ["Jeugdzorg", "Onderwijs en toegankelijke voorzieningen", "Sport en cultuur"],
                    attention: "Controleer de gevolgen voor bereikbaarheid en toegankelijkheid."), onSave: { _ in nil }))),
            ("passage-reader", AnyView(PassageReaderView(point: point, showSource: { _, _ in }))),
            ("focus-editor", AnyView(FocusEditor(initial: "", apply: { _ in }))),
            ("export", AnyView(ExportOptionsView(workspace: restoredWorkspace(archive), onlySelection: false))),
            ("tutorial", AnyView(TutorialView(staticPreview: true)))
        ] {
            for (orientation, size) in sizes {
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
                let originalController = window.rootViewController
                defer { window.rootViewController = originalController }
                let controller = UIHostingController(rootView: view
                    .tint(AppTheme.accent)
                    .buttonStyle(FocusSecondaryButtonStyle())
                    .disclosureGroupStyle(FullRowDisclosureGroupStyle())
                    .preferredColorScheme(.dark))
                controller.overrideUserInterfaceStyle = .dark
                let container = UIViewController()
                window.rootViewController = container
                container.addChild(controller)
                container.view.addSubview(controller.view)
                controller.didMove(toParent: container)
                controller.view.frame = CGRect(origin: .zero, size: size)
                window.makeKeyAndVisible()
                try await Task.sleep(nanoseconds: 350_000_000)
                controller.view.frame = CGRect(origin: .zero, size: size)
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                XCTAssertEqual(controller.traitCollection.userInterfaceStyle, .dark)
                XCTAssertGreaterThan(controller.view.bounds.width, 600)
                let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                    controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("ipad-\(viewName)-\(orientation).png"))
                let attachment = XCTAttachment(image: image)
                attachment.name = "CommissieWijzer iPad \(viewName) \(orientation)"
                attachment.lifetime = .keepAlways
                add(attachment)
                controller.willMove(toParent: nil)
                controller.view.removeFromSuperview()
                controller.removeFromParent()
            }
        }
    }

    func testNarrowResponsiveScreensAtDefaultAndAccessibilityTextSizes() async throws {
        let defaults = UserDefaults.standard
        let previousPDFChoice = defaults.object(forKey: "showPDFPane")
        defer {
            if let previousPDFChoice { defaults.set(previousPDFChoice, forKey: "showPDFPane") }
            else { defaults.removeObject(forKey: "showPDFPane") }
        }
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mac-v1", withExtension: "spdfwork"))
        let archive = try WorkspaceArchive.read(fixture)
        let workspace = restoredWorkspace(archive)
        let document = try XCTUnwrap(workspace.document)
        let errorWorkspace = restoredWorkspace(archive)
        errorWorkspace.processingMessage = "Fictieve foutmelding voor de iPad-weergavetest."
        let busyWorkspace = restoredWorkspace(archive)
        busyWorkspace.busy = true
        let point = Insight(title: "Fictief aandachtspunt", summary: "Een korte fictieve samenvatting.",
                            relevance: "relevant", question: "", quote: "De raad bespreekt het voorstel.", page: 1)
        let secondPoint = Insight(title: "Tweede fictief punt", summary: "Een tweede fictieve samenvatting.",
                                  relevance: "", question: "", quote: "De uitvoering start in januari.", page: 2)
        let table = DocumentTable(id: "ipad-layout-fixture", title: "Fictieve tabel", pages: [1],
                                  headers: ["Onderwerp", "2025"], rows: [["Fietspad", "12"]],
                                  notes: [], reliable: false, recognizedWithOCR: true)
        let sourceItem = SourceHighlights.Item(kind: .decisions, page: 1,
                                               quote: document.pages.first.map { String($0.prefix(180)) } ?? "Fictieve bronpassage.")
        var cardSources = CardSourceCollection()
        cardSources.append(point.quote, page: point.page, role: "Geselecteerde passage")
        let selection = SelectionSummary()
        selection.selection = SelectedPDFText(text: "De raad bespreekt het fictieve voorstel voor het fietspad.", pages: [1])
        selection.summary = "De raad bespreekt het voorstel."
        var searchQuery = "fiets"
        let search = UnifiedSearchView(query: Binding(get: { searchQuery }, set: { searchQuery = $0 }),
                                      records: [SearchRecord(id: "fixture", kind: .pdf, title: "Fictief", content: "Het fietspad wordt besproken.", pageLabel: "p. 1", action: .page(1, quote: "Het fietspad wordt besproken."))],
                                      indexing: false, open: { _ in })
        let chartRenderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let chartImage = try XCTUnwrap(chartRenderer.image { context in
            context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
            context.cgContext.fill(CGRect(x: 8, y: 8, width: 48, height: 48))
        }.cgImage)
        let chart = SelectedChart(page: 1, image: chartImage)
        var views: [(String, AnyView)] = [
            ("workbench", AnyView(NavigationStack { SimpleView(workspace: workspace) }.appPresentationContextHost())),
            ("workbench-pdf", AnyView(NavigationStack { SimpleView(workspace: restoredWorkspace(archive)) }.appPresentationContextHost())),
            ("settings", AnyView(AppSettingsView())),
            ("committees", AnyView(CommitteeManagerView())),
            ("committee-editor", AnyView(CommitteeDefinitionEditor(title: "Commissie aanpassen",
                definition: CommitteeDefinition(id: "layout-fixture", revision: "1",
                    name: "Samenleving en gemeentelijke voorzieningen",
                    topics: ["Jeugdzorg", "Onderwijs en toegankelijke voorzieningen", "Sport en cultuur"],
                    attention: "Controleer de gevolgen voor bereikbaarheid en toegankelijkheid."), onSave: { _ in nil }))),
            ("focus-editor", AnyView(FocusEditor(initial: "", apply: { _ in }))),
            ("export", AnyView(ExportOptionsView(workspace: workspace, onlySelection: false))),
            ("comparison", AnyView(InsightComparisonSheet(points: [point, secondPoint], showSource: { _, _, _ in }))),
            ("passage-reader", AnyView(PassageReaderView(point: point, showSource: { _, _ in }, showsFindings: true))),
            ("card-reader", AnyView(CardPassageReaderView(point: point, sources: cardSources, showSource: { _, _ in }))),
            ("source-context", AnyView(SourceBoundEvidenceView(item: sourceItem, pages: document.pages, showSource: { _, _ in }))),
            ("document-chat", AnyView(DocumentChatView(session: DocumentChatSession(), document: document,
                                                        pages: [1], model: "", focus: "", showSource: { _, _ in }))),
            ("glossary", AnyView(GlossaryView(document: document, tutorialPreview: true, showPage: { _ in }))),
            ("search", AnyView(search)),
            ("selection-summary", AnyView(SelectionSummaryCard(session: selection))),
            ("chosen-passages", AnyView(ChosenPassagesView(workspace: workspace, showSource: { _, _ in }))),
            ("table-explanation", AnyView(TableExplanationView(tables: [table], showPage: { _ in }, tutorialExpanded: true))),
            ("ocr-table-review", AnyView(OCRTableReviewView(table: table, data: document.data, save: { _ in }))),
            ("chart-area", AnyView(ChartAreaView(page: 1, select: { _ in }))),
            ("chart-analysis", AnyView(ChartAnalysisView(selected: chart,
                                                          initialExplanation: ChartExplanation(kind: "bar", title: "Fictief diagram", summary: "Een fictieve toelichting.", observations: [], visibleValues: [], caution: "Controleer de PDF.")))),
            ("processing-busy", AnyView(ProcessingSplashView(workspace: busyWorkspace))),
            ("processing-error", AnyView(ProcessingSplashView(workspace: errorWorkspace))),
            ("tutorial", AnyView(TutorialView(staticPreview: true)))
        ]
        // Avoid initiating an account catalog refresh from a render-only test.
        if !ChatGPTAccount.shared.isSignedIn || !ChatGPTAccount.shared.models.isEmpty {
            views.append(("model-switch", AnyView(ChatGPTModelSwitchView(workspace: workspace))))
        }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LayoutVerification", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (dynamicTypeName, dynamicType, highContrast) in [("default", DynamicTypeSize.large, false),
                                                              ("accessibility-high-contrast", DynamicTypeSize.accessibility3, true)] {
            for (viewName, view) in views {
                if viewName == "workbench" { defaults.set(false, forKey: "showPDFPane") }
                if viewName == "workbench-pdf" { defaults.set(true, forKey: "showPDFPane") }
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
                let originalController = window.rootViewController
                defer { window.rootViewController = originalController }
                let controller = UIHostingController(rootView: view.environment(\.dynamicTypeSize, dynamicType)
                    .tint(AppTheme.accent)
                    .buttonStyle(FocusSecondaryButtonStyle())
                    .disclosureGroupStyle(FullRowDisclosureGroupStyle())
                    .preferredColorScheme(.dark))
                controller.overrideUserInterfaceStyle = .dark
                controller.traitOverrides.accessibilityContrast = highContrast ? .high : .normal
                let container = UIViewController()
                window.rootViewController = container
                container.addChild(controller)
                container.view.addSubview(controller.view)
                controller.didMove(toParent: container)
                controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 900)
                window.makeKeyAndVisible()
                try await Task.sleep(nanoseconds: 350_000_000)
                controller.view.frame = CGRect(x: 0, y: 0, width: 400, height: 900)
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                XCTAssertEqual(controller.view.bounds.width, 400)
                XCTAssertEqual(controller.traitCollection.userInterfaceStyle, .dark)
                let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                    controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("ipad-narrow-\(viewName)-\(dynamicTypeName).png"))
                let attachment = XCTAttachment(image: image)
                attachment.name = "CommissieWijzer narrow iPad \(viewName) \(dynamicTypeName)"
                attachment.lifetime = .keepAlways
                add(attachment)
                controller.willMove(toParent: nil)
                controller.view.removeFromSuperview()
                controller.removeFromParent()
            }
        }
    }

    private func restoredWorkspace(_ archive: WorkspaceArchive) -> SimpleWorkspace {
        let workspace = SimpleWorkspace()
        try? workspace.restore(archive, persist: false)
        return workspace
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
#endif
