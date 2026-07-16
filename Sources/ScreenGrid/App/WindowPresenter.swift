import AppKit

/// Lazily creates and re-presents one auxiliary window (Settings, About).
/// The app is an accessory with no Dock icon, so presenting also activates
/// it; the window is kept alive across closes and simply re-fronted.
@MainActor
final class WindowPresenter {
    private let title: String
    private let makeContentViewController: () -> NSViewController
    private var window: NSWindow?

    init(title: String, content: @escaping () -> NSViewController) {
        self.title = title
        self.makeContentViewController = content
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: makeContentViewController())
            window.title = title
            window.styleMask.subtract([.miniaturizable, .resizable])
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
