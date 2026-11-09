import SwiftUI
import XCTest
@testable import CommissieWijzer

#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
final class QuestionsLayoutTests: XCTestCase {
    func testQuestionListAndEditorRenderInNativeHostingViews() async throws {
        let workspace = try makeWorkspace()
        let document = try XCTUnwrap(workspace.document)
        let documentID = workspace.documentID
        let questions = workspace.meetingQuestions
        var captures = Set<Data>()

        #if os(iOS)
        let wideWidth: CGFloat = 900
        #else
        let wideWidth: CGFloat = 1_000
        #endif
        let listLayouts: [(String, CGSize)] = [
            ("wide", CGSize(width: wideWidth, height: 760)),
            ("compact", CGSize(width: 420, height: 700))
        ]
        for (layout, size) in listLayouts {
            let list = MeetingPreparationView(workspace: workspace, documentID: documentID, pdf: document.data,
                close: {}, draftQuestion: { _, _ in }, editQuestion: { _ in XCTFail("Rendering must not open an editor.") })
            let png = try await capture(list, size: size, name: "questions-list-\(layout)")
            XCTAssertTrue(captures.insert(png).inserted)
        }

        let question = try XCTUnwrap(questions.first)
        let request = MeetingQuestionEditorRequest(documentID: documentID, draft: question, editingExisting: true)
        let editor = MeetingQuestionEditor(request: request, pdf: document.data) { _ in
            XCTFail("Rendering must not save a question.")
            return false
        }
        let editorPNG = try await capture(editor, size: CGSize(width: 540, height: 560), name: "questions-editor")
        XCTAssertTrue(captures.insert(editorPNG).inserted)
        #if os(iOS)
        let compactEditorPNG = try await capture(editor.environment(\.dynamicTypeSize, .accessibility3),
            size: CGSize(width: 380, height: 560), name: "questions-editor-compact-large-text")
        XCTAssertTrue(captures.insert(compactEditorPNG).inserted)
        #endif

        XCTAssertEqual(workspace.documentID, documentID)
        XCTAssertEqual(workspace.meetingQuestions, questions)
    }

    private func makeWorkspace() throws -> SimpleWorkspace {
        let sourceText = "De raad bespreekt in december de proef met buurtbussen."
        let pdf = try BriefingPDF.data(
            document: OpenPDF(name: "Voorbeeldstad.pdf", data: Data(), pages: [], findings: []),
            insights: [], analyzed: false, title: sourceText)
        let workspace = SimpleWorkspace()
        workspace.document = OpenPDF(name: "Voorbeeldstad.pdf", data: pdf, pages: [sourceText], findings: [])
        workspace.showsWelcome = false
        let passage = ChosenPassage(title: "Evaluatie van de buurtbusproef", note: "",
            text: sourceText, pages: [1], sources: [.init(page: 1, quote: sourceText)])
        workspace.chosenPassages = [passage]
        let source = MeetingQuestionSource(passage: passage)
        for question in [
            MeetingQuestion(question: "Welke informatie krijgt de raad vóór het besluit over het vervolg?",
                answer: "De raad ontvangt een overzicht van het gebruik, de kosten en de bereikbaarheid.",
                status: .answered, source: source),
            MeetingQuestion(question: "Wanneer verschijnt de evaluatie?", status: .toAsk, source: source),
            MeetingQuestion(question: "Wie vraagt de gegevens per wijk op?", status: .followUp, source: source)
        ] {
            XCTAssertTrue(workspace.saveMeetingQuestion(question, expectedDocumentID: workspace.documentID))
        }
        return workspace
    }

    private func capture(_ view: some View, size: CGSize, name: String) async throws -> Data {
        let content = view
            .frame(width: size.width, height: size.height)
            .background(AppTheme.background)
            .tint(AppTheme.accent)
            .environment(\.colorScheme, .dark)
        #if os(iOS)
        let png = try await renderOnIPad(content, size: size)
        #else
        let png = try renderOnMac(content, size: size)
        #endif
        XCTAssertGreaterThan(png.count, 1_000, "\(name) should contain a rendered image.")
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let path = ProcessInfo.processInfo.environment["CW_QUESTIONS_UI_RENDER_DIR"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        }
        return png
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
