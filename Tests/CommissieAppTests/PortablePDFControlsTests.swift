import XCTest
import PDFKit
@testable import CommissieWijzer

@MainActor
final class PortablePDFControlsTests: XCTestCase {
    func testSourceNavigationAndLiteralSelectionUseTheOriginalPDF() throws {
        let quote = "De raad bespreekt het voorstel."
        let data = try BriefingPDF.data(document: OpenPDF(name: "Bron.pdf", data: Data(), pages: [], findings: []),
                                        insights: [], analyzed: false, title: quote)
        let document = try XCTUnwrap(PDFDocument(data: data))
        let selection = try XCTUnwrap(PDFPassageLocator.selection(in: document, page: 1, quote: quote))
        XCTAssertEqual(selection.string, quote)
        let sources = PDFControls.pageSources(for: selection, in: document, pages: [1])
        XCTAssertEqual(sources.map(\.page), [1])
        XCTAssertEqual(sources.map(\.quote), [quote])
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 700, height: 800))
        view.document = document
        let controls = PDFControls()
        controls.view = view
        controls.pin(.init(id: "source", page: 1, quote: quote))
        XCTAssertEqual(controls.pinned?.quote, quote)
        XCTAssertFalse(view.highlightedSelections?.isEmpty ?? true)
        controls.resetHighlight()
        XCTAssertNil(controls.pinned)
        XCTAssertNil(view.highlightedSelections)
    }
}
