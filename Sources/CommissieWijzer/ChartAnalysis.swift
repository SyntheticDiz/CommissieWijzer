import AppKit
import FoundationModels
import PDFKit
import Vision

struct SelectedChart: Identifiable {
    let id = UUID()
    let page: Int
    let image: CGImage
}

enum ChartImageRenderer {
    static func render(page: PDFPage, region: CGRect, scale: CGFloat = 2) -> CGImage? {
        let pageBounds = page.bounds(for: .cropBox)
        let crop = region.standardized.intersection(pageBounds)
        guard !crop.isNull, crop.width >= 30, crop.height >= 30 else { return nil }
        let width = Int(ceil(crop.width * scale))
        let height = Int(ceil(crop.height * scale))
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -crop.minX, y: -crop.minY)
        page.draw(with: .cropBox, to: context)
        return context.makeImage()
    }
}

struct ChartExplanation: Codable, Sendable {
    let kind: String
    let title: String
    let summary: String
    let observations: [String]
    let visibleValues: [String]
    let caution: String
}

enum ChartAnalysisService {
    static func unavailableReason() -> String? {
        guard #available(macOS 27.0, *) else { return "Beeldanalyse met Apple Intelligence vereist macOS 27 of nieuwer." }
        if let reason = AppleAIService.unavailability() { return reason }
        guard SystemLanguageModel.default.capabilities.contains(.vision) else {
            return "Het geïnstalleerde Apple-model kan nog geen afbeeldingen analyseren. Werk macOS en Apple Intelligence bij."
        }
        return nil
    }

    static func analyze(_ image: CGImage) async throws -> ChartExplanation {
        if let reason = unavailableReason() { throw AppError(message: reason) }
        guard #available(macOS 27.0, *) else { throw AppError(message: "Beeldanalyse vereist macOS 27.") }
        try Task.checkCancellation()
        let recognized = try await Task.detached(priority: .userInitiated) { try recognizeText(in: image) }.value
        let instructions = """
        Analyseer alleen de aangeleverde uitsnede als cirkel- of staafdiagram. Antwoord in het Nederlands.
        Als dit geen herkenbaar diagram is, zet kind op 'geen diagram'. Gebruik uitsluitend zichtbaar leesbare labels,
        legenda en waarden. Leid geen exacte waarde af uit de hoogte van een staaf of grootte van een taartpunt.
        Verzin geen oorzaak, trend buiten de getoonde categorieën of ontbrekende percentages. Noem onduidelijkheden.
        Schrijf een korte uitleg, maximaal vier concrete observaties en maximaal zes expliciet afleesbare waarden.
        """
        let prompt = Prompt {
            "Lees dit diagram. Herkende tekst ter controle: \(recognized.joined(separator: " | "))."
            Attachment(image).label("Geselecteerd diagram uit de PDF")
        }
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
        let response = try await session.respond(to: prompt, generating: AppleChartDescription.self,
                                                 options: GenerationOptions(temperature: 0, maximumResponseTokens: 650))
        try Task.checkCancellation()
        let raw = response.content
        let described = ([raw.summary] + raw.observations).joined(separator: " ").lowercased()
        let kind: String
        if raw.kind.lowercased() == "geen diagram" {
            if described.contains("staaf") || described.contains("bar-grafiek") { kind = "staafdiagram" }
            else if described.contains("cirkel") || described.contains("taart") { kind = "cirkeldiagram" }
            else { kind = "geen diagram" }
        } else { kind = raw.kind }
        guard kind != "geen diagram" else {
            throw AppError(message: "In deze uitsnede is geen duidelijk cirkel- of staafdiagram herkend. Selecteer het diagram met titel en legenda opnieuw.")
        }
        let checked = ChartValueCheck.filter(raw.visibleValues, against: recognized)
        let observations = ChartValueCheck.filter(raw.observations, against: recognized)
        let summary = ChartValueCheck.isSupported(raw.summary, by: recognized)
            ? raw.summary : "De exacte waarden zijn niet betrouwbaar uit de uitsnede af te lezen. Bekijk het diagram in de PDF."
        let title = ChartValueCheck.isSupported(raw.title, by: recognized) ? raw.title : kind.capitalized
        let caution = ChartValueCheck.isSupported(raw.caution, by: recognized)
            ? raw.caution : "Controleer labels, waarden en eenheden aan de bron."
        return ChartExplanation(kind: kind, title: title, summary: summary,
                                observations: observations, visibleValues: checked,
                                caution: caution.isEmpty ? "Controleer labels, waarden en eenheden aan de bron." : caution)
    }

    private static func recognizeText(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}

enum ChartValueCheck {
    private static let numberPattern = try! NSRegularExpression(pattern: #"\d+(?:[.,]\d+)*"#)

    static func isSupported(_ text: String, by recognized: [String]) -> Bool {
        let source = recognized.joined(separator: " ").replacingOccurrences(of: ",", with: ".")
        let candidate = text.replacingOccurrences(of: ",", with: ".")
        func numbers(in value: String) -> Set<String> {
            Set(numberPattern.matches(in: value, range: NSRange(value.startIndex..., in: value))
                .compactMap { Range($0.range, in: value).map { String(value[$0]) } })
        }
        return numbers(in: candidate).isSubset(of: numbers(in: source))
    }

    static func filter(_ values: [String], against recognized: [String]) -> [String] {
        Array(values.filter { isSupported($0, by: recognized) }.prefix(6))
    }
}

@available(macOS 27.0, *)
@Generable
private struct AppleChartDescription {
    @Guide(description: "Kies staafdiagram of cirkeldiagram als die vormen zichtbaar zijn. Alleen geen diagram als er echt geen diagram is.", .anyOf(["staafdiagram", "cirkeldiagram", "geen diagram"]))
    var kind: String
    var title: String
    var summary: String
    @Guide(description: "Maximaal vier observaties over zichtbare verhoudingen of categorieën.", .maximumCount(4))
    var observations: [String]
    @Guide(description: "Maximaal zes letterlijk afleesbare waarde-labelcombinaties.", .maximumCount(6))
    var visibleValues: [String]
    var caution: String
}
