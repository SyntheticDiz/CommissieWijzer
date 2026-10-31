#if os(iOS)
import Foundation
import XCTest
@testable import CommissieWijzer

private struct LiveChatGPTSmokeResponse: Decodable {
    let overview: String
    let bullets: [String]
}

final class LiveChatGPTSmokeTests: XCTestCase {
    func testLiveChatGPTProducesDutchSummaryForFictionalProposal() async throws {
        guard ProcessInfo.processInfo.environment["CW_RUN_LIVE_CHATGPT"] == "1" else {
            throw XCTSkip("Set CW_RUN_LIVE_CHATGPT=1 to call the signed-in ChatGPT account.")
        }

        let profile = await ChatGPTConnection.shared.savedProfile()
        let signedInProfile = try XCTUnwrap(profile, "A saved ChatGPT account is required for this explicitly enabled live test.")
        _ = signedInProfile // Check presence without retaining or logging identity fields.

        let catalog = try await ChatGPTConnection.shared.refreshModelCatalog()
        let availableModels = catalog.models
        let savedModelID = UserDefaults.standard.string(forKey: ChatGPTPreferences.modelKey)
        let model = availableModels.first(where: { $0.id == savedModelID }) ??
            availableModels.sorted(by: Self.prefersLowerReasoning).first
        let selectedModel = try XCTUnwrap(model, "The signed-in account returned no usable ChatGPT models.")
        let effort = Self.lowestEffort(for: selectedModel)

        let fictionalInput = "FICTIEF VOORBEELD — gemeente Lindeveen. Het college stelt voor om in 2027 drie bushaltes toegankelijker te maken. De raming is 42.000 euro uit het bestaande mobiliteitsbudget. De raad bespreekt het voorstel op 12 november. Het voorstel noemt geen planning voor de uitvoering."
        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["overview", "bullets"],
            "properties": [
                "overview": ["type": "string"],
                "bullets": [
                    "type": "array",
                    "items": ["type": "string"],
                    "minItems": 1,
                    "maxItems": 5
                ]
            ]
        ]
        let body: [String: Any] = [
            "model": AIConfiguration.chatGPTModel(selectedModel.id, effort: effort),
            "instructions": "Vat de fictieve raadsnotitie neutraal samen in het Nederlands. Gebruik alleen genoemde feiten. Geef een korte overview en één tot vijf concrete bullets. Behoud voorstellen als voorstellen.",
            "input": fictionalInput,
            "text": ["format": ["type": "json_schema", "name": "fictional_municipal_proposal_summary", "schema": schema]]
        ]
        let response = try await ChatGPTService.response(body: body)
        let decoded = try JSONDecoder().decode(LiveChatGPTSmokeResponse.self, from: Data(response.utf8))

        XCTAssertFalse(decoded.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue((1...5).contains(decoded.bullets.count))
        XCTAssertTrue(decoded.bullets.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

        let attachmentText = "Model: \(selectedModel.id)\nFictieve invoer: \(fictionalInput)\nAntwoord: \(String(response.prefix(3_000)))"
        let attachment = XCTAttachment(string: attachmentText)
        attachment.name = "Live ChatGPT smoke response (fictional input)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func lowestEffort(for model: ChatGPTModel) -> String {
        model.reasoningEfforts.sorted { effortRank($0) < effortRank($1) }.first ?? "auto"
    }

    private static func prefersLowerReasoning(_ lhs: ChatGPTModel, _ rhs: ChatGPTModel) -> Bool {
        let left = lhs.reasoningEfforts.map(effortRank).min() ?? 0
        let right = rhs.reasoningEfforts.map(effortRank).min() ?? 0
        if left != right { return left < right }
        return lhs.id < rhs.id
    }

    private static func effortRank(_ effort: String) -> Int {
        switch effort {
        case "none": 0
        case "low": 1
        case "medium": 2
        case "high": 3
        case "xhigh": 4
        case "max": 5
        default: 6
        }
    }
}
#endif
