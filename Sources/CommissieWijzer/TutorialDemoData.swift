import AppKit
import CoreText
import PDFKit

/// In-memory example data for the tutorial. It is never loaded from or written to the user's files.
@MainActor enum TutorialDemoData {
    static let quote = "De gemeente stelt voor een apart fietspad bij het station aan te leggen."
    static let pages = [
        "Conceptvoorstel fietsverbinding. De gemeente onderzoekt een veiligere route bij het station. COA betekent Centraal Orgaan opvang asielzoekers.",
        "De route verbindt het station met de wijk. De uitwerking volgt na overleg.",
        "De geraamde kosten bedragen 300.000 euro. Het bedrag is nog niet vastgesteld.",
        quote + " De raad bespreekt het voorstel in november.",
        "Planning: na bespreking kan de gemeente het ontwerp verder uitwerken.",
        "Raming fietspad. 2026: 300.000 euro. 2027: 350.000 euro."
    ]

    static let insight = Insight(
        title: "Apart fietspad bij het station",
        summary: "De gemeente stelt een nieuwe fietsverbinding voor. De raad moet er nog over spreken.",
        relevance: "", question: "Welke gevolgen heeft dit voor het budget?",
        quote: quote, page: 4)

    static func makeWorkspace() -> SimpleWorkspace {
        let workspace = SimpleWorkspace()
        workspace.document = OpenPDF(name: "Commissiestuk.pdf", data: pdfData(), pages: pages, findings: [])
        workspace.showsWelcome = false
        workspace.page = 4
        workspace.status = "Verwerking afgerond"
        workspace.analyzed = true
        workspace.neutralAnalysis = true
        workspace.analysisState = .complete
        workspace.insights = [insight]
        workspace.keyPointsReady = true
        workspace.keyPoints = [
            .init(kind: .decisions, page: 4, quote: quote, title: "Voorstel voor een apart fietspad", decisionStatus: "Voorstel", importance: 1),
            .init(kind: .amounts, page: 3, quote: "De geraamde kosten bedragen 300.000 euro.", title: "Raming: € 300.000", importance: 1),
            .init(kind: .dates, page: 4, quote: "De raad bespreekt het voorstel in november.", title: "Bespreking in november", importance: 1)
        ]
        workspace.documentSummary = DocumentSummary(
            digest: .init(overview: "De gemeente onderzoekt een apart fietspad bij het station. Het voorstel noemt een raming van € 300.000 en een bespreking door de raad in november.", bullets: ["Het fietspad is een voorstel; er is nog geen besluit."]),
            sections: [
                .init(page: 3, digest: .init(overview: "De kosten zijn geraamd op € 300.000.", bullets: [])),
                .init(page: 4, digest: .init(overview: quote + " De raad bespreekt het voorstel in november.", bullets: []))
            ])
        workspace.tables = [.init(id: "tutorial-table", title: "Raming fietspad", pages: [6],
                                  headers: ["Onderdeel", "2026", "2027"], rows: [["Fietspad", "€ 300.000", "€ 350.000"]],
                                  notes: [], reliable: true)]
        return workspace
    }

    static func pdfData() -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        let font = CTFontCreateWithName("Helvetica" as CFString, 15, nil)
        let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font]
        for (pageIndex, text) in pages.enumerated() {
            context.beginPDFPage(nil)
            for (lineIndex, line) in (["Fictief commissiestuk · PDF-pagina \(pageIndex + 1)", ""] + text.components(separatedBy: ". ")).enumerated() {
                let content = line.hasSuffix(".") || line.isEmpty ? line : line + "."
                let textLine = CTLineCreateWithAttributedString(NSAttributedString(string: content, attributes: attributes))
                context.textPosition = CGPoint(x: 48, y: 775 - lineIndex * 35)
                CTLineDraw(textLine, context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}
