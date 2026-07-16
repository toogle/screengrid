import CoreGraphics
import Darwin
import Foundation
import Testing

@testable import ScreenGrid

@MainActor
@Suite struct CommandTapDetectorTests {
    /// A left-⌘ `flagsChanged` event: `down` chooses press vs. release,
    /// `at` is the timestamp in seconds converted to real mach ticks —
    /// the same units hardware events carry.
    private func leftCommandEvent(down: Bool, at seconds: TimeInterval) -> CGEvent {
        let event = CGEvent(source: nil)!
        event.type = .flagsChanged
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(Keys.leftCommand))
        event.flags = down ? CGEventFlags(rawValue: Keys.deviceLeftCommandMask | CGEventFlags.maskCommand.rawValue) : []

        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let ticks = seconds * 1_000_000_000 * Double(info.denom) / Double(info.numer)
        event.timestamp = CGEventTimestamp(ticks)
        return event
    }

    private func detectorFiredTap(pressToRelease: TimeInterval) -> Bool {
        let detector = CommandTapDetector()
        var fired = false
        detector.onTap = { fired = true }

        let press = leftCommandEvent(down: true, at: 100)
        detector.handle(event: press, type: .flagsChanged)
        let release = leftCommandEvent(down: false, at: 100 + pressToRelease)
        detector.handle(event: release, type: .flagsChanged)
        return fired
    }

    /// A press released in under 0.2 s is a tap.
    @Test func quickTapFires() {
        #expect(detectorFiredTap(pressToRelease: 0.05))
    }

    /// A hold of 0.2 s or longer must never show the overlay. Guards the
    /// mach-tick → seconds conversion: on Apple Silicon a tick is 125/3 ns,
    /// so treating tick deltas as nanoseconds would let holds of up to
    /// ~8.3 s pass as "taps".
    @Test(arguments: [0.25, 1.0, 5.0])
    func holdLongerThanMaxDurationIsRejected(seconds: TimeInterval) {
        #expect(!detectorFiredTap(pressToRelease: seconds))
    }

    /// Any other key going down between press and release rejects the tap —
    /// the user is typing a ⌘-shortcut, however quick.
    @Test func keyDownDuringHoldIsRejected() {
        let detector = CommandTapDetector()
        var fired = false
        detector.onTap = { fired = true }

        detector.handle(event: leftCommandEvent(down: true, at: 100), type: .flagsChanged)
        let key = CGEvent(source: nil)!
        key.type = .keyDown
        detector.handle(event: key, type: .keyDown)
        detector.handle(event: leftCommandEvent(down: false, at: 100.05), type: .flagsChanged)
        #expect(!fired)
    }

    /// A left-⌘ press with another modifier already down (⇧⌘, ⌃⌘, …) is a
    /// shortcut in progress, never a tap.
    @Test func pressWithOtherModifierHeldIsRejected() {
        let detector = CommandTapDetector()
        var fired = false
        detector.onTap = { fired = true }

        let press = leftCommandEvent(down: true, at: 100)
        press.flags.insert(.maskShift)
        detector.handle(event: press, type: .flagsChanged)
        detector.handle(event: leftCommandEvent(down: false, at: 100.05), type: .flagsChanged)
        #expect(!fired)
    }
}
