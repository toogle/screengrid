import AppKit
import ApplicationServices
import Carbon
import IOKit.hid

/// Tracks the three states the event tap depends on: the Accessibility and
/// Input Monitoring privacy grants, and whether secure input mode (a focused
/// password field) is currently swallowing keyboard events — while it is,
/// activation is refused (`flagsChanged` still reaches the tap, but keyDowns
/// would leak past it) and the menu bar shows a passive state.
@MainActor
final class PermissionsMonitor {
    struct Status: Equatable {
        var accessibility: Bool
        var inputMonitoring: Bool
        var secureInputActive: Bool

        /// True when the event tap can function.
        var satisfied: Bool { accessibility && inputMonitoring }
    }

    var onStatusChange: ((Status) -> Void)?

    private var pollTimer: Timer?
    private var lastStatus: Status?

    func currentStatus() -> Status {
        Status(
            accessibility: AXIsProcessTrusted(),
            inputMonitoring: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted,
            secureInputActive: IsSecureEventInputEnabled()
        )
    }

    /// Polls for status changes; there is no notification API for either
    /// permission or for secure input, so polling is the standard approach.
    func startMonitoring(interval: TimeInterval = 2.0) {
        stopMonitoring()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { // scheduled on the main run loop
                self?.poll()
            }
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Shows the system Accessibility consent prompt (first launch).
    func requestAccessibilityPrompt() {
        // kAXTrustedCheckOptionPrompt is a C global the compiler can't prove
        // concurrency-safe; its value is the stable literal below.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Deep link to System Settings → Privacy & Security → Accessibility.
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Deep link to System Settings → Privacy & Security → Input Monitoring.
    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    private func poll() {
        let status = currentStatus()
        if status != lastStatus {
            lastStatus = status
            onStatusChange?(status)
        }
    }
}
