import XCTest
@testable import CommissieWijzer

final class AccentPaletteTests: XCTestCase {
    func testEveryPresetKeepsPrimaryActionTextLegibleAcrossStates() {
        let text = (red: 0.06, green: 0.10, blue: 0.14)
        for preset in AccentPreset.allCases {
            XCTAssertGreaterThanOrEqual(AccentPreset.contrast(text, preset.actionRGB), 4.5,
                                        "\(preset.rawValue) default action fill")
            XCTAssertGreaterThanOrEqual(AccentPreset.contrast(text, preset.actionHoverRGB), 4.5,
                                        "\(preset.rawValue) hover action fill")
            XCTAssertGreaterThanOrEqual(AccentPreset.contrast(text, preset.actionPressedRGB), 4.5,
                                        "\(preset.rawValue) pressed action fill")
            XCTAssertGreaterThanOrEqual(AccentPreset.contrast(preset.darkAccentRGB,
                                                               (red: 0.15, green: 0.18, blue: 0.22)), 3.0,
                                        "\(preset.rawValue) dark-surface accent visibility")
        }

        XCTAssertGreaterThan(Set(AccentPreset.allCases.map { $0.lightAccentRGB.red }).count, 1,
                             "Presets should visibly differ in light appearance.")
        XCTAssertGreaterThan(Set(AccentPreset.allCases.map { $0.darkAccentRGB.blue }).count, 1,
                             "Presets should visibly differ in dark appearance.")
    }

    func testPersistentPreferenceRoundTripsAndUnknownValuesFallBackToCyan() throws {
        let suiteName = "CommissieWijzer.AccentPaletteTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(AccentPreset.resolve(nil), .cyan)
        XCTAssertEqual(AccentPreset.resolve("unknown-value"), .cyan)
        XCTAssertEqual(AccentPreset.resolve("purple"), .purple)

        let firstPalette = AccentPalette(defaults: defaults)
        XCTAssertEqual(firstPalette.selected, .cyan)
        firstPalette.selected = .purple
        XCTAssertEqual(defaults.string(forKey: AccentPalette.preferenceKey), "purple")

        let reloadedPalette = AccentPalette(defaults: defaults)
        XCTAssertEqual(reloadedPalette.selected, .purple)

        defaults.set("invalid", forKey: AccentPalette.preferenceKey)
        XCTAssertEqual(AccentPalette(defaults: defaults).selected, .cyan)
    }
}
