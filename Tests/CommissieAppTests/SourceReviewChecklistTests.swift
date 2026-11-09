import XCTest
@testable import CommissieWijzer

final class SourceReviewChecklistTests: XCTestCase {
    func testChecklistUsesExactCoverageAndCurrentHumanChecks() {
        let checked = point("De raad heeft een voorstel besproken.")
        let unchecked = point("De evaluatie staat nog op de agenda.", page: 3)
        let unreadableOCR = DocumentTable(id: "image", title: "Afbeelding", pages: [2], headers: ["Post"],
            rows: [["Bijdrage"]], notes: [], reliable: false, recognizedWithOCR: true)
        let uncertainText = DocumentTable(id: "text", title: "Tekst", pages: [3], headers: ["Post"],
            rows: [["Bijdrage"]], notes: [], reliable: false)
        let coverage = DocumentCoverage.make(pages: ["Bron 1", " ", "Bron 3", "Bron 4"], completedAnalysisPages: [1, 2],
            analysisState: .incomplete, tables: [unreadableOCR, uncertainText])
        let checklist = SourceReviewChecklist.make(coverage: coverage, analysisNeedsAttention: true, points: [checked, unchecked]) {
            PointAnnotation(checkedSignature: $0.id == checked.id ? PointAnnotation.signature(checked) : "outdated")
        }
        XCTAssertEqual(checklist.unreadablePages, [2])
        XCTAssertEqual(checklist.readableOutsideConfirmedAnalysis, [3, 4])
        XCTAssertTrue(checklist.analysisNeedsAttention)
        XCTAssertEqual(checklist.uncertainTableIDs, ["text"])
        XCTAssertEqual(checklist.unconfirmedOCRTableIDs, ["image"])
        XCTAssertEqual(checklist.checkedPointCount, 1)
        XCTAssertEqual(checklist.firstUncheckedPoint?.id, unchecked.id)

        let old = DocumentCoverage.make(pages: ["Bron 1"], completedAnalysisPages: nil, analysisState: .complete, tables: [])
        let unknown = SourceReviewChecklist.make(coverage: old, analysisNeedsAttention: false, points: []) { _ in .init() }
        XCTAssertNil(unknown.readableOutsideConfirmedAnalysis)
        XCTAssertNil(unknown.firstUncheckedPoint)
    }

    func testChecklistHasNoPendingTasksForKnownCoverageAndConfirmedSources() {
        let checked = point("De proef is besproken.")
        var image = DocumentTable(id: "image", title: "Afbeelding", pages: [1], headers: ["Post"],
            rows: [["Bijdrage"]], notes: [], reliable: true, recognizedWithOCR: true)
        image.ocrReview = OCRTableReview(confirmedSignature: image.reviewSignature)
        let text = DocumentTable(id: "text", title: "Tekst", pages: [1], headers: ["Post"],
            rows: [["Bijdrage"]], notes: [], reliable: true)
        let coverage = DocumentCoverage.make(pages: ["Bron 1"], completedAnalysisPages: [1],
            analysisState: .complete, tables: [image, text])
        let checklist = SourceReviewChecklist.make(coverage: coverage, analysisNeedsAttention: false, points: [checked]) {
            PointAnnotation(checkedSignature: PointAnnotation.signature($0))
        }
        XCTAssertTrue(checklist.unreadablePages.isEmpty)
        XCTAssertEqual(checklist.readableOutsideConfirmedAnalysis, [])
        XCTAssertFalse(checklist.analysisNeedsAttention)
        XCTAssertTrue(checklist.uncertainTableIDs.isEmpty)
        XCTAssertTrue(checklist.unconfirmedOCRTableIDs.isEmpty)
        XCTAssertEqual(checklist.checkedPointCount, 1)
        XCTAssertNil(checklist.firstUncheckedPoint)
    }

    private func point(_ quote: String, page: Int = 1) -> Insight {
        Insight(title: "Controlepunt", summary: quote, relevance: "", question: "", quote: quote, page: page)
    }
}
