import AppKit
import CoreGraphics

/// The single session-level, HID-placed `CGEventTap`. Listens to
/// `flagsChanged`/`keyDown`/`keyUp` plus mouse buttons and scroll — the
/// mouse events are needed to reject ⌘-taps and dismiss the overlay on
/// physical mouse activity. The tap is created active so the handler can
/// consume keyboard events while a session is live; in the idle phase the
/// handler passes everything through, so the tap is effectively passive.
///
/// The run-loop source is installed on the main run loop, so the C callback
/// always runs on the main thread and hops straight onto the main actor —
/// consume/pass decisions must be synchronous, which rules out an async hop.
@MainActor
final class EventTapManager {
    enum Verdict {
        case pass
        case consume
    }

    /// Synchronous event decision. Return `.consume` to swallow the event.
    var handler: ((CGEvent, CGEventType) -> Verdict)?

    /// Called when the system disables the tap (timeout, or the user revoked
    /// a permission). The manager has already attempted re-enabling;
    /// `recovered` reports whether that worked.
    var onTapDisabled: ((_ recovered: Bool) -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    enum Failure: Error {
        /// Tap creation failed — almost always missing Accessibility /
        /// Input Monitoring permission.
        case tapCreationFailed
    }

    func start() throws {
        guard tap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.scrollWheel.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw Failure.tapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    fileprivate func handleCallback(type: CGEventType, event: CGEvent) -> Verdict {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            var recovered = false
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
                recovered = CGEvent.tapIsEnabled(tap: tap)
            }
            onTapDisabled?(recovered)
            return .pass
        }
        return handler?(event, type) ?? .pass
    }
}

/// C callback trampoline. Runs on the main thread because the tap's run-loop
/// source lives on the main run loop (see `EventTapManager.start`).
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    // Safe: assumeIsolated runs synchronously on this (main) thread, so the
    // event never actually crosses an isolation boundary.
    nonisolated(unsafe) let event = event
    let verdict = MainActor.assumeIsolated {
        manager.handleCallback(type: type, event: event)
    }

    switch verdict {
    case .pass:
        return Unmanaged.passUnretained(event)
    case .consume:
        return nil
    }
}
