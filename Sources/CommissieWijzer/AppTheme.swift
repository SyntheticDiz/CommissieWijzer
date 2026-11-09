import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum AppTheme {
    #if canImport(AppKit)
    static func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
    #elseif canImport(UIKit)
    static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
    #endif
    static let background = adaptive(.init(red: 0.94, green: 0.95, blue: 0.97, alpha: 1), .init(red: 0.09, green: 0.11, blue: 0.14, alpha: 1))
    static let surface = adaptive(.init(white: 1, alpha: 1), .init(red: 0.15, green: 0.18, blue: 0.22, alpha: 1))
    static let paneSurface = adaptive(.init(red: 0.97, green: 0.98, blue: 0.99, alpha: 1), .init(red: 0.12, green: 0.14, blue: 0.17, alpha: 1))
    static let border = adaptive(.init(red: 0.84, green: 0.86, blue: 0.89, alpha: 1), .init(red: 0.25, green: 0.29, blue: 0.34, alpha: 1))
    private static var currentPalette: AccentPreset { AccentPalette.shared.selected }
    private static func color(_ rgb: (red: Double, green: Double, blue: Double)) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
    static var selection: Color {
        let palette = currentPalette
        let light = palette.selectionLightRGB, dark = palette.selectionDarkRGB
        return adaptive(.init(red: light.red, green: light.green, blue: light.blue, alpha: 1),
                        .init(red: dark.red, green: dark.green, blue: dark.blue, alpha: 1))
    }
    static var accent: Color {
        let palette = currentPalette
        return adaptive(.init(red: palette.lightAccentRGB.red, green: palette.lightAccentRGB.green, blue: palette.lightAccentRGB.blue, alpha: 1),
                        .init(red: palette.darkAccentRGB.red, green: palette.darkAccentRGB.green, blue: palette.darkAccentRGB.blue, alpha: 1))
    }
    static var primaryAction: Color { color(currentPalette.actionRGB) }
    static var primaryActionHover: Color { color(currentPalette.actionHoverRGB) }
    static var primaryActionPressed: Color { color(currentPalette.actionPressedRGB) }
    static let primaryActionText = Color(red: 0.06, green: 0.10, blue: 0.14)
    static var focusRing: Color { accent }
    static let buttonSurface = adaptive(.init(white: 1, alpha: 1), .init(red: 0.19, green: 0.22, blue: 0.27, alpha: 1))
    static let buttonHover = adaptive(.init(red: 0.88, green: 0.90, blue: 0.93, alpha: 1), .init(red: 0.27, green: 0.31, blue: 0.37, alpha: 1))
    static let buttonDisabled = adaptive(.init(red: 0.92, green: 0.93, blue: 0.95, alpha: 1), .init(red: 0.13, green: 0.15, blue: 0.18, alpha: 1))
    static let cardRadius: CGFloat = 18
}

/// Shared reading surface; system contrast preferences retain a visible outline.
private struct ReadingSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .overlay { RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(contrast == .increased ? Color.primary.opacity(0.5) : AppTheme.border.opacity(0.55), lineWidth: 1)
                .allowsHitTesting(false).accessibilityHidden(true) }
            .shadow(color: .black.opacity(contrast == .increased ? 0 : 0.045), radius: 7, x: 0, y: 2)
    }
}
extension View {
    func readingSurface() -> some View { modifier(ReadingSurface()) }
    func workbenchPaneSurface() -> some View { modifier(WorkbenchPaneSurface()) }
}

private struct WorkbenchPaneSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.background(AppTheme.paneSurface, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(contrast == .increased ? Color.primary.opacity(0.6) : AppTheme.border.opacity(0.8), lineWidth: 1)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
    }
}
