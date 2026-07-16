import CoreGraphics
import Foundation

/// Recognizes the activation gesture: press and full release of the *left*
/// Command key in under `Timing.commandTapMaxDuration`, with no other key,
/// modifier, or mouse event in between — so ⌘-shortcuts (⌘C, ⌘Tab, …) and
/// modifier-clicks never trigger the overlay. Fed every tapped event while
/// the session is idle; fires `onTap` when a clean tap completes.
@MainActor
final class CommandTapDetector {
    var onTap: (() -> Void)?

    /// CGEvent timestamp (mach ticks) of the pending left-⌘ press, or nil
    /// when no press is being tracked.
    private var pressTimestamp: CGEventTimestamp?

    /// Seconds per mach tick. CGEvent timestamps are mach_absolute_time
    /// units, *not* nanoseconds: on Apple Silicon a tick is 125/3 ns, so
    /// treating tick deltas as nanoseconds undercounts ~41.7× and a multi-
    /// second ⌘ hold would still pass the 0.2 s tap check.
    private static let secondsPerTick: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()

    func handle(event: CGEvent, type: CGEventType) {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event)
        default:
            // Any key, mouse button, or scroll between press and release
            // rejects the tap — the user is doing a ⌘-shortcut or clicking.
            pressTimestamp = nil
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        guard keyCode == Keys.leftCommand else {
            // Some other modifier changed state mid-tap → reject.
            pressTimestamp = nil
            return
        }

        let rawFlags = event.flags.rawValue
        let leftCommandDown = rawFlags & Keys.deviceLeftCommandMask != 0

        if leftCommandDown {
            // Track the press only if no other modifier is down at press
            // time (⌃⌘, ⌥⌘, ⇧⌘, right ⌘ held, …) — a shortcut in progress.
            let otherModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate]
            let cleanPress = event.flags.isDisjoint(with: otherModifiers)
                && rawFlags & Keys.deviceRightCommandMask == 0
            pressTimestamp = cleanPress ? event.timestamp : nil
        } else {
            // Left ⌘ released — a clean, fast enough press/release is a tap.
            defer { pressTimestamp = nil }
            guard let pressed = pressTimestamp else { return }
            let elapsedSeconds = Double(event.timestamp &- pressed) * Self.secondsPerTick
            if elapsedSeconds < Timing.commandTapMaxDuration {
                onTap?()
            }
        }
    }

    /// Forget any in-flight press (e.g. when a session starts or the tap stops).
    func reset() {
        pressTimestamp = nil
    }
}
