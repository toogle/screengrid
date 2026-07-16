import Foundation
import ServiceManagement

/// Launch-at-login via `SMAppService`. Only functional when running from a
/// proper .app bundle; the bare SPM executable reports disabled and ignores
/// writes.
@MainActor
final class LoginItemManager {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItemManager: failed to \(enabled ? "register" : "unregister"): \(error)")
        }
    }
}
