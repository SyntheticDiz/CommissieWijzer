import AppKit
import CoreText
import PDFKit

let pageSize = CGSize(width: 595.28, height: 841.89) // A4, points
let ink = NSColor(srgbRed: 0.09, green: 0.18, blue: 0.24, alpha: 1)
let muted = NSColor(srgbRed: 0.34, green: 0.41, blue: 0.44, alpha: 1)
let teal = NSColor(srgbRed: 0.08, green: 0.43, blue: 0.41, alpha: 1)

let content = NSMutableAttributedString()

func append(_ value: String, size: CGFloat, weight: NSFont.Weight = .regular,
            color: NSColor = ink, spacingBefore: CGFloat = 0, spacingAfter: CGFloat = 4,
            lineSpacing: CGFloat = 2) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.paragraphSpacingBefore = spacingBefore
    paragraph.paragraphSpacing = spacingAfter
    paragraph.lineSpacing = lineSpacing
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    content.append(NSAttributedString(string: value + "\n", attributes: attributes))
}

append("Toegankelijke bibliotheek in Voorbeeldstad", size: 21, weight: .semibold, spacingAfter: 5, lineSpacing: 1)
append("Raadsvoorstel · Commissie SOD · concept van 30 oktober 2026", size: 10.5, color: muted, spacingAfter: 15, lineSpacing: 1)

append("DOEL EN VOORSTEL", size: 10.5, weight: .bold, color: teal, spacingBefore: 1, spacingAfter: 4, lineSpacing: 1)
append("Het college stelt voor de hoofdingang van de openbare bibliotheek in Voorbeeldstad toegankelijker te maken. Het plan omvat een automatische toegangsdeur, een voelbare en contrasterende looproute naar de balie, en duidelijke routeborden. Dit is een voorstel ter bespreking; er is nog geen krediet toegekend en er is geen opdracht verstrekt.", size: 12.5, spacingAfter: 9)

append("VOORGESTELDE UITGAVEN", size: 10.5, weight: .bold, color: teal, spacingBefore: 1, spacingAfter: 4, lineSpacing: 1)
append("• Automatische deur en bediening: € 12.000\n• Voelbare looproute en contrastmarkering: € 6.500\n• Routeborden en plaatsing: € 3.500\nTotaal aangevraagd: € 22.000 inclusief btw. Dit zijn ramingen, geen offertes.", size: 12.5, spacingAfter: 9)

append("GEVRAAGD BESLUIT EN VERANTWOORDELIJKHEID", size: 10.5, weight: .bold, color: teal, spacingBefore: 1, spacingAfter: 4, lineSpacing: 1)
append("De raad wordt gevraagd op 19 november 2026 te besluiten of maximaal € 22.000 beschikbaar wordt gesteld. Een positief besluit is nog geen opdracht aan een leverancier. Na goedkeuring is het college verantwoordelijk voor inkoop en uitvoering.", size: 12.5, spacingAfter: 9)

append("TERMIJN, RISICO’S EN VOORWAARDEN", size: 10.5, weight: .bold, color: teal, spacingBefore: 1, spacingAfter: 4, lineSpacing: 1)
append("Bij goedkeuring levert het college uiterlijk 15 januari 2027 een uitvoerings- en onderhoudsplan aan de raad. De raming kan afwijken van de offertes. De ingang en vluchtroute moeten tijdens werkzaamheden bruikbaar blijven. Als de offertes samen boven het aangevraagde bedrag uitkomen, vraagt het college eerst een nieuw raadsbesluit aan. De uitvoering start pas na vaststelling van het budget en controle van de toegankelijkheidsmaatregelen.", size: 12.5, spacingAfter: 9)

append("BRONSTATUS", size: 10.5, weight: .bold, color: teal, spacingBefore: 1, spacingAfter: 4, lineSpacing: 1)
append("Bedragen zijn ramingen. Offertes, uitvoeringstoestemming en een raadsbesluit ontbreken nog. Dit document bevat uitsluitend broninformatie en geen AI-analyse.", size: 12.5, spacingAfter: 0)

func drawLabel(_ value: String, at point: CGPoint, context: CGContext, size: CGFloat, color: NSColor, weight: NSFont.Weight) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color
    ]))
    context.textPosition = point
    CTLineDraw(line, context)
}

var mediaBox = CGRect(origin: .zero, size: pageSize)
let buffer = NSMutableData()
guard let consumer = CGDataConsumer(data: buffer as CFMutableData),
      let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    fatalError("Could not create sample PDF context")
}

context.beginPDFPage(nil)
context.setFillColor(NSColor.white.cgColor)
context.fill(mediaBox)

drawLabel("Fictief voorbeeld – geen echt raadsvoorstel", at: CGPoint(x: 32, y: 800),
          context: context, size: 9, color: teal, weight: .bold)

let bodyPath = CGMutablePath()
bodyPath.addRect(CGRect(x: 32, y: 64, width: pageSize.width - 64, height: 716))
let framesetter = CTFramesetterCreateWithAttributedString(content)
let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), bodyPath, nil)
let visibleRange = CTFrameGetVisibleStringRange(frame)
guard visibleRange.length == content.length else {
    fatalError("Sample text does not fit on one A4 page")
}
CTFrameDraw(frame, context)

context.setStrokeColor(NSColor(srgbRed: 0.82, green: 0.86, blue: 0.84, alpha: 1).cgColor)
context.setLineWidth(0.7)
context.move(to: CGPoint(x: 32, y: 51))
context.addLine(to: CGPoint(x: pageSize.width - 32, y: 51))
context.strokePath()
drawLabel("Fictief voorbeeld – geen echt raadsvoorstel", at: CGPoint(x: 32, y: 32),
          context: context, size: 8.5, color: muted, weight: .medium)
context.endPDFPage()
context.closePDF()

let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("AppStore", isDirectory: true)
    .appendingPathComponent("Sample.pdf")
try buffer.write(to: outputURL)

guard let sample = PDFDocument(url: outputURL), sample.pageCount == 1,
      let page = sample.page(at: 0) else {
    fatalError("Sample PDF must contain exactly one page")
}
let bounds = page.bounds(for: .mediaBox)
guard abs(bounds.width - pageSize.width) < 1, abs(bounds.height - pageSize.height) < 1,
      page.string?.contains("geen echt raadsvoorstel") == true else {
    fatalError("Sample PDF page size or selectable text validation failed")
}

print("Created one-page fictional Dutch council proposal PDF")
