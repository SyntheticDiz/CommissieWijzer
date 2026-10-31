import XCTest
import PDFKit
@testable import CommissieWijzer

@MainActor
final class PortableWorkspaceTests: XCTestCase {
    /// The checked-in fixture is created by the Mac archive test from fictional
    /// data. Both targets decode, restore and re-encode that same format-v1 file.
    func testMacWorkdocumentRemainsCompleteOnBothPlatforms() throws {
        #if os(iOS)
        let input = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "mac-v1", withExtension: "spdfwork"))
        #else
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")
        let input = ProcessInfo.processInfo.environment["CW_IPAD_ROUNDTRIP_INPUT"].map { URL(fileURLWithPath: $0) }
            ?? fixtures.appendingPathComponent("mac-v1.spdfwork")
        #endif
        let original = try WorkspaceArchive.read(input)
        XCTAssertEqual(original.formatVersion, 1)
        XCTAssertEqual(original.name, "Begroting.pdf")
        XCTAssertFalse(original.pdf.isEmpty)
        XCTAssertFalse(original.insights.isEmpty)
        XCTAssertFalse(original.annotations.isEmpty)
        XCTAssertFalse(original.chosenPassages?.isEmpty ?? true)
        XCTAssertFalse(original.savedChatThreads?.isEmpty ?? true)
        XCTAssertFalse(original.savedChartAnalyses?.isEmpty ?? true)
        XCTAssertFalse(original.savedSelectionSummaries?.isEmpty ?? true)
        let workspace = SimpleWorkspace()
        workspace.generateCommitteeReview = { _, _, _, _ in
            XCTFail("Opening a portable workdocument must not invoke AI")
            throw CancellationError()
        }
        try workspace.restore(original, persist: false)
        XCTAssertEqual(workspace.document?.data, original.pdf)
        XCTAssertEqual(workspace.document?.pages, original.pages)
        XCTAssertEqual(workspace.annotations, original.annotations)
        XCTAssertEqual(workspace.starred, original.starred)
        XCTAssertEqual(workspace.chosenPassages.count, original.chosenPassages?.count)
        XCTAssertEqual(workspace.savedChatThreads.count, original.savedChatThreads?.count)
        XCTAssertEqual(workspace.savedChartAnalyses.first?.imagePNG, original.savedChartAnalyses?.first?.imagePNG)

        #if os(iOS)
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iPad-RoundTrip.spdfwork")
        #else
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".spdfwork")
        defer { try? FileManager.default.removeItem(at: output) }
        #endif
        let resaved = try workspace.archive(readingPage: original.page, viewState: original.viewState)
        XCTAssertNotEqual(resaved.snapshotID, original.snapshotID, "A fresh portable save receives a new snapshot identity")
        try resaved.write(output)
        let reloaded = try WorkspaceArchive.read(output)
        let before = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? NSDictionary
        let after = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reloaded)) as? NSDictionary
        let beforeFields = try XCTUnwrap(before as? [String: Any])
        let afterFields = try XCTUnwrap(after as? [String: Any])
        for (field, value) in beforeFields where field != "snapshotID" {
            guard let resavedValue = afterFields[field] else {
                XCTFail("Re-saving the restored workspace dropped archive field '\(field)'")
                continue
            }
            XCTAssertTrue(
                (value as? NSObject)?.isEqual(resavedValue) == true,
                "Re-saving the restored workspace changed archive field '\(field)'"
            )
        }
    }
}
