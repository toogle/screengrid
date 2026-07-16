import AppKit

/// Entry point. ScreenGrid is a menu bar utility (`LSUIElement`): no Dock
/// icon, no main window. When run as a bare SPM executable the accessory
/// activation policy is applied at runtime; the bundled build gets it from
/// `Support/Info.plist`.
@main
struct ScreenGridMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
