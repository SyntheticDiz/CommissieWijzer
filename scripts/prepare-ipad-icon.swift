import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Keep the existing CW artwork. iPad App Store icons require an opaque canvas;
// the OS applies the outer corner mask instead of macOS's transparent canvas.
let arguments = CommandLine.arguments
guard arguments.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: arguments[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == 1024, image.height == 1024,
      let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Expected a 1024px CW source icon and an output path")
}
context.setFillColor(CGColor(red: 16.0 / 255, green: 38.0 / 255, blue: 52.0 / 255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: arguments[2]) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not prepare the opaque iPad icon")
}
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not save the iPad icon") }
