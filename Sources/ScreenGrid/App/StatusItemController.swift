import AppKit
import SwiftUI

/// The menu bar presence: status item with Settings, permission status
/// (only when attention is needed), About, and Quit; launch-at-login lives
/// in the Settings window. ScreenGrid is always active while running —
/// there is no manual enable/disable. The icon doubles as a health
/// indicator: warning triangle when permissions are missing or the tap is
/// broken, dimmed while secure input silences the tap.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let session: SessionController
    private let permissions: PermissionsMonitor
    private let loginItem = LoginItemManager()

    private var onboardingPopover: NSPopover?

    private lazy var settingsWindow = WindowPresenter(title: "ScreenGrid Settings") { [loginItem] in
        NSHostingController(rootView: SettingsView(settings: .shared, loginItem: loginItem))
    }
    private lazy var aboutWindow = WindowPresenter(title: "About ScreenGrid") {
        NSHostingController(rootView: AboutView())
    }

    init(session: SessionController, permissions: PermissionsMonitor) {
        self.session = session
        self.permissions = permissions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        refresh()
    }

    /// Re-renders the icon and menu; closes the onboarding popover once both
    /// permissions are granted.
    func refresh() {
        let status = permissions.currentStatus()
        updateIcon(status: status)
        statusItem.menu = buildMenu(status: status)

        if let popover = onboardingPopover {
            if status.satisfied {
                popover.close()
            } else if let host = popover.contentViewController as? NSHostingController<PermissionsOnboardingView> {
                host.rootView = onboardingView(status: status)
            }
        }
    }

    // MARK: Onboarding

    /// Shows the permissions popover anchored to the status item.
    func showPermissionsOnboarding() {
        guard onboardingPopover == nil, let button = statusItem.button else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: onboardingView(status: permissions.currentStatus())
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        onboardingPopover = popover
    }

    func popoverDidClose(_ notification: Notification) {
        onboardingPopover = nil
    }

    private func onboardingView(status: PermissionsMonitor.Status) -> PermissionsOnboardingView {
        PermissionsOnboardingView(
            accessibilityGranted: status.accessibility,
            inputMonitoringGranted: status.inputMonitoring,
            openAccessibility: { [weak self] in self?.permissions.openAccessibilitySettings() },
            openInputMonitoring: { [weak self] in self?.permissions.openInputMonitoringSettings() }
        )
    }

    // MARK: Icon

    private func updateIcon(status: PermissionsMonitor.Status) {
        guard let button = statusItem.button else { return }
        let broken = !status.satisfied || session.isTapBroken
        button.image = NSImage(
            systemSymbolName: broken ? "exclamationmark.triangle" : "square.grid.3x3",
            accessibilityDescription: broken ? "ScreenGrid — attention required" : "ScreenGrid"
        )
        // Passive look while a password field's secure input mode makes the
        // ⌘-tap temporarily unavailable.
        button.appearsDisabled = !broken && status.secureInputActive
    }

    // MARK: Menu

    private func buildMenu(status: PermissionsMonitor.Status) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if status.secureInputActive {
            let notice = NSMenuItem(title: "Paused: secure input is active", action: nil, keyEquivalent: "")
            notice.isEnabled = false
            menu.addItem(notice)
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        if !status.satisfied {
            let permissionsItem = NSMenuItem(
                title: "Permissions Required…",
                action: #selector(showPermissionsFromMenu),
                keyEquivalent: ""
            )
            permissionsItem.target = self
            menu.addItem(permissionsItem)
        }

        let aboutItem = NSMenuItem(title: "About ScreenGrid", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit ScreenGrid", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: Actions

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func openAbout() {
        aboutWindow.show()
    }

    @objc private func showPermissionsFromMenu() {
        showPermissionsOnboarding()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
