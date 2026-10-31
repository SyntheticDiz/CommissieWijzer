#if os(iOS)
import Foundation
import XCTest
@testable import CommissieWijzer

private struct LiveAppleAISmokeResponse: Decodable {
    let overview: String
    let bullets: [String]
}

final class LiveAppleAISmokeTests: XCTestCase {
    @available(iOS 26.0, *)
    func testLiveAppleFoundationModelProducesDutchSummary() async throws {
        guard ProcessInfo.processInfo.environment["CW_RUN_LIVE_APPLE_AI"] == "1" else {
            throw XCTSkip("Set CW_RUN_LIVE_APPLE_AI=1 or run the CommissieWijzer-LiveAI scheme to call Apple's on-device model.")
        }
        if let reason = AppleAIService.unavailability() {
            throw XCTSkip("Apple's on-device Dutch model is unavailable: \(reason)")
        }

        let body: [String: Any] = [
            "model": AppleAIService.modelID,
            "instructions": "Vat de fictieve raadsnotitie neutraal samen in het Nederlands. Gebruik alleen genoemde feiten. Geef een korte overview en één tot vijf concrete bullets. Behoud voorstellen als voorstellen.",
            "input": "FICTIEF VOORBEELD — gemeente Lindeveen. Het college stelt voor om in 2027 drie bushaltes toegankelijker te maken. De raming is 42.000 euro uit het bestaande mobiliteitsbudget. De raad bespreekt het voorstel op 12 november. Het voorstel noemt geen planning voor de uitvoering.",
            "text": ["format": ["name": "document_summary"]]
        ]
        let response = try await AppleAIService.response(body: body)
        let decoded = try JSONDecoder().decode(LiveAppleAISmokeResponse.self, from: Data(response.utf8))

        XCTAssertFalse(decoded.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue((1...5).contains(decoded.bullets.count))
        XCTAssertTrue(decoded.bullets.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

        let attachment = XCTAttachment(string: String(response.prefix(3_000)))
        attachment.name = "Live Apple AI smoke response (fictional input)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
