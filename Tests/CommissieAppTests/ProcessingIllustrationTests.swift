import XCTest
@testable import CommissieWijzer

final class ProcessingIllustrationTests: XCTestCase {
    func testIllustrationFollowsActivePresentationStage() {
        XCTAssertEqual(select(.committee, status: "Voorbereiding voor commissie"), .committee)
        XCTAssertEqual(select(.points, status: "Alinea 4 beoordelen"), .points)
        XCTAssertEqual(select(.summary, status: "Document samenvatten"), .summary)
        XCTAssertEqual(select(.highlights, status: "Kernpunten beoordelen"), .highlights)
    }

    func testPartyComparisonIllustrationRequiresMatchingStatusAndPointsStage() {
        XCTAssertEqual(select(.points, status: "Vergelijken met partijprogramma"), .partyComparison)
        XCTAssertEqual(select(.points, status: "Programmapassages vergelijken"), .partyComparison)
        XCTAssertEqual(select(.points, status: "AI-analyse: 3 van 7…"), .partyComparison)
        XCTAssertEqual(select(.points, status: "Samenhang controleren aan oorspronkelijke bronnen…"), .partyComparison)
        XCTAssertEqual(select(.points, status: "Bronnen controleren aan oorspronkelijke passages…"), .partyComparison)
        XCTAssertEqual(select(.points, status: "Alineapunten: 3", comparing: false), .points)
        XCTAssertEqual(select(.summary, status: "Programmapassages vergelijken"), .summary)
    }

    func testDocumentIllustrationRemainsFallbackWhenNoStageIsActive() {
        XCTAssertEqual(ProcessingPresentation.Illustration.select(activeStage: nil, status: "Verwerking bezig", busy: true), .document)
        XCTAssertEqual(ProcessingPresentation.Illustration.select(activeStage: .points, status: "Alinea 1", busy: false), .document)
    }

    private func select(_ stage: ProcessingPresentation.Stage, status: String, comparing: Bool = true) -> ProcessingPresentation.Illustration {
        ProcessingPresentation.Illustration.select(activeStage: stage, status: status, busy: true, comparingPartyProgram: comparing)
    }
}
