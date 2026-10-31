#if os(iOS)
import SwiftUI
import UIKit

// Source-compatible image/font names for the shared PDF/OCR reading views.
// Rendering and document handling use native UIKit implementations on iPad.
typealias NSImage = UIImage
typealias NSColor = UIColor
typealias NSFont = UIFont
typealias NSSize = CGSize

extension Image {
    init(nsImage image: UIImage) { self.init(uiImage: image) }
}
extension Color {
    init(nsColor color: UIColor) { self.init(uiColor: color) }
}
extension UIColor {
    static var windowBackgroundColor: UIColor { .systemBackground }
    static var textBackgroundColor: UIColor { .secondarySystemBackground }
    static var controlBackgroundColor: UIColor { .secondarySystemBackground }
}

extension UIImage {
    convenience init(cgImage: CGImage, size: CGSize) {
        self.init(cgImage: cgImage)
    }
    func cgImage(forProposedRect: UnsafeMutablePointer<CGRect>?, context: Any?, hints: [String: Any]?) -> CGImage? {
        cgImage
    }
}

extension UIFont {
    var fontNameForMatching: String { fontName }
}
extension UIFontDescriptor.SymbolicTraits {
    static var bold: Self { .traitBold }
}

/// Give atomic local saves time to finish when iPadOS backgrounds the scene.
/// Expiration cancels the operation; archive writes retain their atomic behavior.
@MainActor enum iPadBackgroundExecution {
    static func perform(_ operation: @escaping @MainActor () async -> Void) {
        let lifetime = Lifetime()
        let task = Task { @MainActor in
            defer { lifetime.end() }
            await operation()
        }
        lifetime.identifier = UIApplication.shared.beginBackgroundTask(withName: "Werkdocument lokaal bewaren") {
            Task { @MainActor in task.cancel(); lifetime.end() }
        }
    }
    @MainActor private final class Lifetime {
        var identifier = UIBackgroundTaskIdentifier.invalid
        func end() {
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }
}
#endif

import SwiftUI

extension View {
    @ViewBuilder func platformCheckboxStyle() -> some View {
        #if os(macOS)
        self.toggleStyle(.checkbox)
        #else
        self.toggleStyle(.switch)
        #endif
    }
    func platformReadingFrame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                              minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
                              alignment: Alignment = .center) -> some View {
        #if os(macOS)
        self.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth,
                   minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment)
        #else
        self.frame(minWidth: 0, idealWidth: idealWidth, maxWidth: maxWidth ?? .infinity,
                   minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment)
        #endif
    }
    func platformSheetSize(width: CGFloat, height: CGFloat? = nil) -> some View {
        #if os(macOS)
        self.frame(width: width, height: height)
        #else
        self.frame(idealWidth: width, maxWidth: .infinity, idealHeight: height, maxHeight: height == nil ? nil : .infinity)
        #endif
    }
    @ViewBuilder func platformToolbarMenuStyle() -> some View {
        #if os(macOS)
        self.menuStyle(.borderlessButton)
        #else
        self.menuStyle(.automatic)
        #endif
    }
    @ViewBuilder func platformTouchTarget() -> some View {
        #if os(iOS)
        self.frame(minWidth: 44, minHeight: 44)
        #else
        self
        #endif
    }
    func onPlatformExit(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        self.onExitCommand(perform: action)
        #else
        self.onKeyPress(.escape) { action(); return .handled }
        #endif
    }
}
