import AppKit

/// Wires the long-lived objects together: permissions, the session state
/// machine (which owns the event tap and overlay), and the status item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissions = PermissionsMonitor()
    private let session = SessionController()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        statusItem = StatusItemController(session: session, permissions: permissions)

        session.onHealthChange = { [weak self] in
            self?.statusItem?.refresh()
        }

        permissions.onStatusChange = { [weak self] status in
            guard let self else { return }
            // Follow permission changes live: tear the tap down when a grant
            // is revoked, come back up when both are (re)granted.
            if status.satisfied {
                self.session.enable()
            } else {
                self.session.disable()
            }
            if status.secureInputActive {
                self.session.secureInputDidActivate()
            }
            self.statusItem?.refresh()
        }
        permissions.startMonitoring()

        if permissions.currentStatus().satisfied {
            session.enable()
        } else {
            permissions.requestAccessibilityPrompt()
            statusItem?.showPermissionsOnboarding()
        }
        statusItem?.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.disable()
    }

    /// An accessory app never shows a menu bar, but key equivalents are
    /// still resolved against the main menu — this is what lets ⌘W close
    /// the Settings and About windows like any other macOS window.
    private func installMainMenu() {
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let fileItem = NSMenuItem()
        fileItem.submenu = fileMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(fileItem)
        NSApp.mainMenu = mainMenu
    }
}
