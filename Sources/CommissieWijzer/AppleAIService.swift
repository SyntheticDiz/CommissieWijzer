import Foundation
import FoundationModels

/// Uses only Apple's on-device model. Never routes to Private Cloud Compute.
enum AppleAIService {
    static let modelID = "spdf-apple-on-device"
    static let sendableResponse: AIService.Request = { body in
        try await response(body: body)
    }

    static func unavailability() -> String? {
        guard #available(macOS 26.0, iOS 26.0, *) else { return "Apple Intelligence vereist macOS 26 of nieuwer. AI-analyse is op deze macOS-versie niet beschikbaar." }
        switch SystemLanguageModel.default.availability {
        case .available:
            return SystemLanguageModel.default.supportsLocale(Locale(identifier: "nl")) ? nil : "Het geïnstalleerde Apple-model ondersteunt Nederlands nog niet. Werk macOS en de modellen bij."
        case .unavailable(.deviceNotEligible): return "Dit apparaat ondersteunt Apple Intelligence niet."
        case .unavailable(.appleIntelligenceNotEnabled): return "Schakel Apple Intelligence in via de systeeminstellingen."
        case .unavailable(.modelNotReady): return "Het Apple-model is nog niet klaar. Laat het systeem de modellen downloaden en controleer opnieuw."
        case .unavailable: return "Apple Intelligence is momenteel niet beschikbaar."
        }
    }

    static func response(body: [String: Any]) async throws -> String {
        if let reason = unavailability() { throw AppError(message: reason) }
        guard #available(macOS 26.0, iOS 26.0, *) else { throw AppError(message: "Apple Intelligence vereist macOS 26.") }
        try Task.checkCancellation()
        let instructions = body["instructions"] as? String ?? ""
        let input = body["input"] as? String ?? ""
        let format = (body["text"] as? [String: Any])?["format"] as? [String: Any]
        switch format?["name"] as? String {
        case "key_point": return try await generate(AppleKeyPoint.self, instructions: instructions, input: input, limit: 250)
        case "apple_question": return try await generate(AppleOneQuestion.self, instructions: instructions, input: input, limit: 250)
        case "apple_program_evidence": return try await generate(AppleProgramEvidence.self, instructions: instructions, input: input, limit: 600)
        case "apple_evidence": return try await generate(AppleEvidence.self, instructions: instructions, input: input, limit: 500)
        case "passage_neutral": return try await generate(ApplePassageEvidence.self, instructions: instructions, input: input, limit: 650)
        case "passage_program": return try await generate(ApplePassageProgramEvidence.self, instructions: instructions, input: input, limit: 650)
        case "apple_review": return try await generate(AppleReview.self, instructions: instructions, input: input, limit: 500)
        case "passage_questions": return try await generate(AppleQuestions.self, instructions: instructions, input: input, limit: 650)
        case "glossary_web": return try await generate(AppleGlossaryWebAnswer.self, instructions: instructions, input: input, limit: 450)
        case "paragraph_summary": return try await generate(AppleParagraphDigest.self, instructions: instructions, input: input, limit: 500)
        case "neutral_outline": return try await generate(AppleNeutralOutline.self, instructions: instructions, input: input, limit: 650)
        case "document_chat": return try await generate(AppleChatAnswer.self, instructions: instructions, input: input, limit: 650)
        case "document_overview": return try await generate(AppleOverview.self, instructions: instructions, input: input, limit: 1600)
        case "document_summary": return try await generate(AppleDigest.self, instructions: instructions, input: input, limit: 400)
        case "program_matches": return try await generate(AppleProgramMatches.self, instructions: instructions, input: input, limit: 700)
        case "committee_categorization": return try await generateCommittee(format: format, assessment: false, instructions: instructions, input: input, limit: 250)
        case "committee_assessment": return try await generateCommittee(format: format, assessment: true, instructions: instructions, input: input, limit: 400)
        default: return try await generate(AppleInsights.self, instructions: instructions, input: input, limit: 700)
        }
    }

    /// Committee enums depend on the selected purpose. Constrain both fields to
    /// those IDs in the actual local schema; unassigned is never a secondary tag.
    @available(macOS 26.0, iOS 26.0, *)
    private static func generateCommittee(format: [String: Any]?, assessment: Bool, instructions: String, input: String, limit: Int) async throws -> String {
        guard let schemaJSON = format?["schema"] as? [String: Any],
              let properties = schemaJSON["properties"] as? [String: Any],
              let category = properties["categoryID"] as? [String: Any],
              let primaryIDs = category["enum"] as? [String],
              let secondary = properties["secondaryCategoryIDs"] as? [String: Any],
              let items = secondary["items"] as? [String: Any],
              let secondaryIDs = items["enum"] as? [String], !secondaryIDs.isEmpty else { throw AppleFailure.invalid }
        let primary = DynamicGenerationSchema(name: "CommitteePrimaryTopic", anyOf: primaryIDs)
        let secondaryTopic = DynamicGenerationSchema(name: "CommitteeSecondaryTopic", anyOf: secondaryIDs)
        var fields: [DynamicGenerationSchema.Property] = []
        if assessment {
            fields += [
                .init(name: "rating", description: "Exact één belangbeoordeling uit de instructie.", schema: .init(name: "CommitteeRating", anyOf: CommitteeAssessmentService.Rating.allCases.map(\.rawValue))),
                .init(name: "reason", description: "Korte Nederlandse reden uitsluitend op basis van de bron.", schema: .init(type: String.self)),
                .init(name: "evidenceQuote", description: "Een letterlijk aaneengesloten citaat uit CORE, exact overgenomen.", schema: .init(type: String.self))
            ]
        }
        fields += [
            .init(name: "categoryID", description: "Eén primaire categorie, of unassigned bij twijfel.", schema: primary),
            .init(name: "secondaryCategoryIDs", description: "Lege lijst [] tenzij duidelijk een ANDER onderwerp voorkomt. Nooit de primaire categorie herhalen.", schema: .init(arrayOf: secondaryTopic, minimumElements: 0, maximumElements: 7))
        ]
        do {
            let schema = try GenerationSchema(root: .init(name: assessment ? "CommitteeAssessment" : "CommitteeCategorization", properties: fields), dependencies: [])
            let model = SystemLanguageModel.default
            if #available(macOS 26.4, iOS 26.4, *) {
                let total = try await model.tokenCount(for: Instructions(instructions)) + model.tokenCount(for: Prompt(input)) + model.tokenCount(for: schema)
                guard total + limit + 256 <= 4096 else { throw AppleFailure.context }
            } else {
                guard instructions.utf8.count + input.utf8.count + limit + 900 <= 4096 else { throw AppleFailure.context }
            }
            let session = LanguageModelSession(model: model, instructions: instructions)
            let response = try await session.respond(to: input, schema: schema, options: GenerationOptions(temperature: 0, maximumResponseTokens: limit))
            try Task.checkCancellation()
            return response.content.jsonString
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            throw AppleFailure.classify(error)
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private static func generate<T: Generable & Encodable>(_ type: T.Type, instructions: String, input: String, limit: Int) async throws -> String {
        do {
            if #available(macOS 26.4, iOS 26.4, *) {
                let model = SystemLanguageModel.default
                let instructionTokens = try await model.tokenCount(for: Instructions(instructions))
                let inputTokens = try await model.tokenCount(for: Prompt(input))
                let schemaTokens = try await model.tokenCount(for: T.generationSchema)
                guard instructionTokens + inputTokens + schemaTokens + limit + 256 <= 4096 else { throw AppleFailure.context }
            } else {
                // Deliberately conservative byte upper bound, including schema overhead.
                guard instructions.utf8.count + input.utf8.count + limit + 900 <= 4096 else { throw AppleFailure.context }
            }
            let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
            let response = try await session.respond(to: input, generating: type, options: GenerationOptions(temperature: 0, maximumResponseTokens: limit))
            try Task.checkCancellation()
            return String(decoding: try JSONEncoder().encode(response.content), as: UTF8.self)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            throw AppleFailure.classify(error)
        }
    }

}

@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct AppleInsights: Codable {
    @Guide(description: "Maximaal drie aandachtspunten; leeg als er geen zijn.", .maximumCount(3))
    var insights: [AppleInsight]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct AppleInsight: Codable {
    var title: String
    var summary: String
    var relevance: String
    var question: String
    @Guide(description: "Kort letterlijk aaneengesloten citaat uit de aangeleverde bronpagina.")
    var quote: String
    var page: Int
}
@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct AppleQuestions: Codable {
    @Guide(description: "Maximaal vijf verschillende vragen; bij aanvullen alleen het gevraagde ontbrekende aantal.", .maximumCount(5))
    var questions: [AppleQuestion]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct AppleQuestion: Codable {
    var question: String
    @Guide(description: "Kort letterlijk broncitaat dat aangeeft op welk stuk de vraag betrekking heeft.")
    var quote: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct AppleProgramMatches: Codable {
    @Guide(description: "Maximaal twee onderbouwde verbanden; leeg bij geen verband.", .maximumCount(2))
    var matches: [AppleProgramMatch]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct AppleProgramMatch: Codable {
    var title: String
    var summary: String
    var relevance: String
    var question: String
    var quote: String
    var programQuote: String
    var programPage: Int
}

@available(macOS 26.0, iOS 26.0, *)
@Generable
private struct AppleDigest: Codable {
    @Guide(description: "Maximaal twee korte neutrale zinnen, uitsluitend expliciete bronfeiten. Behoud voorstel of verzoek als voorstel of verzoek.")
    var overview: String
    @Guide(description: "Maximaal vijf expliciete bronfeiten, zonder nieuwe aannames of onzekerheden; totaal onder 100 woorden.", .maximumCount(5))
    var bullets: [String]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable private struct AppleChatAnswer: Codable {
    @Guide(description: "Brongebonden antwoord in het Nederlands; benoem ontbrekende informatie, maximaal 180 woorden.")
    var answer: String
    @Guide(description: "Maximaal drie letterlijke broncitaten.", .maximumCount(3))
    var citations: [AppleChatCitation]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable private struct AppleChatCitation: Codable {
    var sourceID: String
    var quote: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable private struct AppleNeutralOutline: Codable {
    @Guide(description: "Maximaal drie neutrale samenvattingspunten, elk met broncitaat.", .maximumCount(3))
    var points: [AppleNeutralPoint]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable private struct AppleNeutralPoint: Codable {
    var title: String
    var summary: String
    @Guide(description: "Kort exact aaneengesloten broncitaat.")
    var quote: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleEvidence: Codable {
    @Guide(description: "Maximaal twee punten. Leeg indien geen concreet onderbouwd punt.", .maximumCount(2))
    var points: [AppleEvidencePoint]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleEvidencePoint: Codable {
    var title: String
    @Guide(description: "Eén korte Nederlandse zin met alleen expliciete documentfeiten.")
    var summary: String
    @Guide(description: "Exact één D-bronnummer uit de invoer, bijvoorbeeld D1.")
    var documentID: String
    @Guide(description: "Exact één P-bronnummer bij vergelijking; anders een lege string.")
    var programID: String
    @Guide(description: "Eén korte zin over overeenkomst of spanning; leeg bij neutrale analyse.")
    var relevance: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable private struct ApplePassageEvidence: Codable {
    @Guide(description: "Maximaal drie brongebonden punten; leeg als de passage geen hoofd- of achtergrondpunt bevat.", .maximumCount(3))
    var points: [ApplePassagePoint]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable private struct ApplePassagePoint: Codable {
    var title: String
    var summary: String
    @Guide(description: "Exact document-ID van een CORE-bron, nooit van CONTEXT.") var documentID: String
    @Guide(description: "Alle CORE-bron-ID's die dit punt onderbouwen; documentID verplicht.", .maximumCount(8)) var sourceIDs: [String]
    @Guide(description: "main, background of uncertain.") var relevanceClass: String
    @Guide(description: "Korte reden op basis van expliciete broninformatie.") var relevanceReason: String
    @Guide(description: "Alleen gebruikte context-ID's; leeg als context niet nodig was.") var contextIDs: [String]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable private struct ApplePassageProgramEvidence: Codable {
    @Guide(description: "Maximaal drie concrete programmacontextpunten; leeg als er geen aantoonbare overeenkomst of spanning is.", .maximumCount(3))
    var points: [ApplePassageProgramPoint]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable private struct ApplePassageProgramPoint: Codable {
    var title: String
    var summary: String
    @Guide(description: "Exact document-ID van een CORE-bron.") var documentID: String
    @Guide(description: "Alle CORE-bron-ID's die dit punt onderbouwen; documentID verplicht.", .maximumCount(8)) var sourceIDs: [String]
    @Guide(description: "Exact programma-ID.") var programID: String
    @Guide(description: "Aantoonbare overeenkomst of spanning, los van relevantie.") var relevance: String
    @Guide(description: "main, background of uncertain.") var relevanceClass: String
    @Guide(description: "Korte reden op basis van expliciete broninformatie.") var relevanceReason: String
    @Guide(description: "Alleen gebruikte context-ID's; leeg als context niet nodig was.") var contextIDs: [String]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleReview: Codable {
    @Guide(description: "Maximaal twee korte Nederlandse zinnen met alleen feiten uit D-bronnen. Geen programmatekst of broncodes.")
    var summary: String
    @Guide(description: "Alleen expliciet onderbouwde overeenkomst of spanning, maximaal twee zinnen. Wens blijft wens. Geen onzekerheid verzinnen. Leeg bij neutrale analyse.")
    var relevance: String
    @Guide(description: "D-bronnummers die de herziening onderbouwen. D1 en alle aangeleverde passagebronnen verplicht. Alleen aangeleverde nummers.", .maximumCount(16))
    var sourceIDs: [String]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleProgramEvidence: Codable {
    @Guide(description: "Maximaal twee concrete programmaverbanden. Leeg bij geen verband.", .maximumCount(2))
    var points: [AppleProgramEvidencePoint]
}
@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleProgramEvidencePoint: Codable {
    var title: String
    @Guide(description: "Eén korte Nederlandse zin met alleen expliciete documentfeiten.")
    var summary: String
    @Guide(description: "Verplicht exact D-bronnummer uit DOCUMENT, bijvoorbeeld D1. Nooit leeg.")
    var documentID: String
    @Guide(description: "Verplicht exact P-bronnummer uit PROGRAMMA, bijvoorbeeld P1. Nooit leeg.")
    var programID: String
    @Guide(description: "Eén zin met expliciete overeenkomst of spanning. Wens blijft wens. Evaluatie is geen bewijs voor beëindiging of onzekere voortzetting.")
    var relevance: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleOneQuestion: Codable {
    @Guide(description: "Eén open Nederlandse commissievraag. Geen nieuwe feiten aannemen.")
    var question: String
    @Guide(description: "Verplicht exact één D-bronnummer uit de passage, bijvoorbeeld D1.")
    var sourceID: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleOverview: Codable {
    @Guide(description: "Vat uitsluitend expliciete bronfeiten samen in het Nederlands. Maximaal 25 zinnen, maar zo kort als de bron toelaat. Vul ontbrekende informatie nooit in. Maximaal 500 woorden.")
    var overview: String
    @Guide(description: "Maximaal vijf concrete hoofdpunten.", .maximumCount(5))
    var bullets: [String]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleKeyPoint: Codable {
    var relevant: Bool
    @Guide(description: "Korte concrete Nederlandse beschrijving. Geen nieuwe feiten. Maximaal 30 woorden.")
    var title: String
    @Guide(description: "Belang van 1 tot 3.", .range(1...3))
    var importance: Int
    @Guide(description: "Status uitsluitend voorstel, vastgesteld of onbekend.", .anyOf(["voorstel", "vastgesteld", "onbekend"]))
    var status: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable struct AppleParagraphDigest: Codable {
    @Guide(description: "Korte Nederlandse titel voor de volledige alinea.")
    var title: String
    @Guide(description: "Twee tot vier zinnen over de hele alinea. Maximaal 100 woorden. Alleen bronfeiten, inclusief voorwaarden en uitzonderingen.")
    var summary: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable private struct AppleGlossaryWebAnswer: Codable {
    var fullName: String
    var explanation: String
    var context: String
    var certain: Bool
    var sourceID: Int
    var quote: String
}

@available(macOS 26.0, iOS 26.0, *)
@Generable private struct AppleCommitteeAssessment: Codable {
    @Guide(description: "Exact één waarde.", .anyOf(["important", "relevant", "other", "uncertain", "unassessed"]))
    var rating: String
    @Guide(description: "Korte Nederlandse reden uitsluitend op basis van CORE-brontekst.")
    var reason: String
    @Guide(description: "Niet-lege letterlijke aaneengesloten quote uit CORE, exact overgenomen.")
    var evidenceQuote: String
    @Guide(description: "Exact één geldige categorie-ID uit de instructie of unassigned.")
    var categoryID: String
    @Guide(description: "Alleen geldige andere categorie-ID's uit de instructie; geen duplicaten.", .maximumCount(7))
    var secondaryCategoryIDs: [String]
}

@available(macOS 26.0, iOS 26.0, *)
@Generable private struct AppleCommitteeCategorization: Codable {
    @Guide(description: "Exact één geldige categorie-ID uit de instructie of unassigned.")
    var categoryID: String
    @Guide(description: "Alleen geldige andere categorie-ID’s uit de instructie; geen duplicaten.", .maximumCount(7))
    var secondaryCategoryIDs: [String]
}
