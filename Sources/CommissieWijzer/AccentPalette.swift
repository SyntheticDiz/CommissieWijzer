import SwiftUI
import Observation
import Foundation

enum AccentPreset: String, CaseIterable, Identifiable {
    case cyan, blue, teal, purple, amber

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyan: "Cyaan"
        case .blue: "Blauw"
        case .teal: "Groenblauw"
        case .purple: "Paars"
        case .amber: "Amber"
        }
    }

    var actionRGB: (red: Double, green: Double, blue: Double) {
        switch self {
        case .cyan: (0.64, 0.85, 0.90)
        case .blue: (0.69, 0.81, 0.97)
        case .teal: (0.63, 0.85, 0.78)
        case .purple: (0.81, 0.73, 0.93)
        case .amber: (0.97, 0.83, 0.59)
        }
    }

    var actionHoverRGB: (red: Double, green: Double, blue: Double) {
        let c = actionRGB
        return (min(1, c.red + 0.07), min(1, c.green + 0.04), min(1, c.blue + 0.03))
    }

    var actionPressedRGB: (red: Double, green: Double, blue: Double) {
        let c = actionRGB
        return (max(0, c.red - 0.10), max(0, c.green - 0.09), max(0, c.blue - 0.08))
    }

    var lightAccentRGB: (red: Double, green: Double, blue: Double) {
        switch self {
        case .cyan: (0.13, 0.39, 0.46)
        case .blue: (0.20, 0.39, 0.70)
        case .teal: (0.12, 0.43, 0.36)
        case .purple: (0.40, 0.28, 0.58)
        case .amber: (0.52, 0.34, 0.08)
        }
    }

    var darkAccentRGB: (red: Double, green: Double, blue: Double) {
        switch self {
        case .cyan: (0.64, 0.85, 0.90)
        case .blue: (0.61, 0.76, 0.97)
        case .teal: (0.58, 0.82, 0.74)
        case .purple: (0.78, 0.68, 0.91)
        case .amber: (0.94, 0.77, 0.47)
        }
    }

    var selectionLightRGB: (red: Double, green: Double, blue: Double) {
        let c = lightAccentRGB
        return (0.89 + c.red * 0.05, 0.91 + c.green * 0.05, 0.92 + c.blue * 0.05)
    }

    var selectionDarkRGB: (red: Double, green: Double, blue: Double) {
        let c = darkAccentRGB
        return (0.10 + c.red * 0.12, 0.12 + c.green * 0.12, 0.14 + c.blue * 0.12)
    }

    static func resolve(_ storedValue: String?) -> AccentPreset {
        storedValue.flatMap(AccentPreset.init(rawValue:)) ?? .cyan
    }

    static func relativeLuminance(_ rgb: (red: Double, green: Double, blue: Double)) -> Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    static func contrast(_ first: (red: Double, green: Double, blue: Double),
                         _ second: (red: Double, green: Double, blue: Double)) -> Double {
        let a = relativeLuminance(first), b = relativeLuminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// One observable selection drives all app windows and persists in the production preference store.
@Observable final class AccentPalette {
    static let preferenceKey = "accentPreset"
    static let shared = AccentPalette(defaults: .standard)

    var selected: AccentPreset {
        didSet { defaults.set(selected.rawValue, forKey: Self.preferenceKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        selected = AccentPreset.resolve(defaults.string(forKey: Self.preferenceKey))
    }
}
