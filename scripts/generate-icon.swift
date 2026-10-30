import AppKit
import CoreText

// Native vector artwork: a precisely typeset, optically centered CW monogram.
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
let tile = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 196, yRadius: 196)
NSGradient(starting: NSColor(calibratedRed: 0.063, green: 0.149, blue: 0.204, alpha: 1),
           ending: NSColor(calibratedRed: 0.125, green: 0.267, blue: 0.353, alpha: 1))!.draw(in: tile, angle: 90)

let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 440, nil)
let letters = Array("CW".utf16)
var glyphs = [CGGlyph](repeating: 0, count: letters.count)
CTFontGetGlyphsForCharacters(font, letters, &glyphs, letters.count)
var advances = [CGSize](repeating: .zero, count: letters.count)
CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
let outline = CGMutablePath()
var cursor: CGFloat = 0
for index in glyphs.indices {
    let glyph = CTFontCreatePathForGlyph(font, glyphs[index], nil)!
    outline.addPath(glyph, transform: CGAffineTransform(translationX: cursor, y: 0))
    cursor += advances[index].width - 8
}
let bounds = outline.boundingBoxOfPath
let scale: CGFloat = 674 / bounds.width
let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
    tx: (1024 - bounds.width * scale) / 2 - bounds.minX * scale,
    ty: (1024 - bounds.height * scale) / 2 - bounds.minY * scale)
let mark = CGMutablePath()
mark.addPath(outline, transform: transform)
let context = NSGraphicsContext.current!.cgContext
context.setFillColor(NSColor(calibratedWhite: 0.965, alpha: 1).cgColor)
context.addPath(mark)
context.fillPath()
NSGraphicsContext.restoreGraphicsState()

// SVG exports the very same glyph outlines, with no dependency on installed fonts.
let svgMark = CGMutablePath()
svgMark.addPath(mark, transform: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 1024))
var commands: [String] = []
func number(_ value: CGFloat) -> String { String(format: "%.3f", Double(value)) }
func point(_ p: CGPoint) -> String { number(p.x) + " " + number(p.y) }
svgMark.applyWithBlock { pointer in
    let element = pointer.pointee
    switch element.type {
    case .moveToPoint: commands.append("M" + point(element.points[0]))
    case .addLineToPoint: commands.append("L" + point(element.points[0]))
    case .addQuadCurveToPoint: commands.append("Q" + point(element.points[0]) + " " + point(element.points[1]))
    case .addCurveToPoint: commands.append("C" + point(element.points[0]) + " " + point(element.points[1]) + " " + point(element.points[2]))
    case .closeSubpath: commands.append("Z")
    @unknown default: break
    }
}
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="CommissieWijzer CW">
<defs><linearGradient id="navy" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#20445a"/><stop offset="1" stop-color="#102634"/></linearGradient></defs>
<rect x="56" y="56" width="912" height="912" rx="196" fill="url(#navy)"/>
<path fill="#f6f6f6" d="\(commands.joined(separator: " "))"/>
</svg>
"""
let assets = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Assets", isDirectory: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("CommissieWijzer.png"))
try svg.write(to: assets.appendingPathComponent("CommissieWijzer.svg"), atomically: true, encoding: .utf8)
print("Generated precise CW monogram: 1024px PNG and identical SVG outlines.")
