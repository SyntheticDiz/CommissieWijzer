import XCTest
@testable import CommissieCore

final class PublicSourceCoreSmokeTests: XCTestCase {
    func testSyntheticNeutralTextProducesNoCoreFindings() {
        XCTAssertTrue(Analyzer.analyze(pages: ["The weather is mild today."]).isEmpty)
    }
}
