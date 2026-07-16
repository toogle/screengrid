import Foundation
import Observation

/// User-configurable overlay appearance, persisted in `UserDefaults`.
/// Stage views read these directly; observation re-renders them live while
/// the Settings window tweaks values.
@MainActor
@Observable
final class OverlaySettings {
    static let shared = OverlaySettings()

    enum DefaultValue {
        static let tilesEnabled = true
        static let letterOpacity = 0.55
        static let tileBorderOpacity = 0.25
        static let hairlineOpacity = 0.25
        static let hairlineWidth = 1.0
        static let lineShadowOpacity = 0.7
        static let lineShadowWidth = 1.5
    }

    /// Draw the dark rounded tiles behind letters. With tiles off the
    /// letters render directly over the desktop.
    var tilesEnabled: Bool { didSet { save() } }

    /// White level of every stage's letters (0–1).
    var letterOpacity: Double { didSet { save() } }

    /// White level of the tile borders.
    var tileBorderOpacity: Double { didSet { save() } }

    /// White level of the stage-0 lattice hairlines.
    var hairlineOpacity: Double { didSet { save() } }

    /// Stroke width of the lattice hairlines, in points.
    var hairlineWidth: Double { didSet { save() } }

    /// Darkness of the under-stroke drawn beneath each hairline — the crisp
    /// shadow that keeps the lattice visible on all-white content (0–1).
    var lineShadowOpacity: Double { didSet { save() } }

    /// Extra width of the under-stroke beyond the hairline, in points
    /// (extends half per side); 0 removes the shadow entirely.
    var lineShadowWidth: Double { didSet { save() } }

    private enum Key {
        static let tilesEnabled = "overlay.tilesEnabled"
        static let letterOpacity = "overlay.letterOpacity"
        static let tileBorderOpacity = "overlay.tileBorderOpacity"
        static let hairlineOpacity = "overlay.hairlineOpacity"
        static let hairlineWidth = "overlay.hairlineWidth"
        static let lineShadowOpacity = "overlay.lineShadowOpacity"
        static let lineShadowWidth = "overlay.lineShadowWidth"
    }

    private let defaults = UserDefaults.standard

    private init() {
        tilesEnabled = defaults.object(forKey: Key.tilesEnabled) as? Bool ?? DefaultValue.tilesEnabled
        letterOpacity = defaults.object(forKey: Key.letterOpacity) as? Double ?? DefaultValue.letterOpacity
        tileBorderOpacity = defaults.object(forKey: Key.tileBorderOpacity) as? Double ?? DefaultValue.tileBorderOpacity
        hairlineOpacity = defaults.object(forKey: Key.hairlineOpacity) as? Double ?? DefaultValue.hairlineOpacity
        hairlineWidth = defaults.object(forKey: Key.hairlineWidth) as? Double ?? DefaultValue.hairlineWidth
        lineShadowOpacity = defaults.object(forKey: Key.lineShadowOpacity) as? Double ?? DefaultValue.lineShadowOpacity
        lineShadowWidth = defaults.object(forKey: Key.lineShadowWidth) as? Double ?? DefaultValue.lineShadowWidth
    }

    func resetToDefaults() {
        tilesEnabled = DefaultValue.tilesEnabled
        letterOpacity = DefaultValue.letterOpacity
        tileBorderOpacity = DefaultValue.tileBorderOpacity
        hairlineOpacity = DefaultValue.hairlineOpacity
        hairlineWidth = DefaultValue.hairlineWidth
        lineShadowOpacity = DefaultValue.lineShadowOpacity
        lineShadowWidth = DefaultValue.lineShadowWidth
    }

    private func save() {
        defaults.set(tilesEnabled, forKey: Key.tilesEnabled)
        defaults.set(letterOpacity, forKey: Key.letterOpacity)
        defaults.set(tileBorderOpacity, forKey: Key.tileBorderOpacity)
        defaults.set(hairlineOpacity, forKey: Key.hairlineOpacity)
        defaults.set(hairlineWidth, forKey: Key.hairlineWidth)
        defaults.set(lineShadowOpacity, forKey: Key.lineShadowOpacity)
        defaults.set(lineShadowWidth, forKey: Key.lineShadowWidth)
    }
}
