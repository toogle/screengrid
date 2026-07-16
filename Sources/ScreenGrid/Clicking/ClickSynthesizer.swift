import CoreGraphics

/// Which mouse button a synthesized click presses. ⌃ held at the instant of
/// a click-producing keypress selects `.right` (secondary click).
enum MouseButton: Equatable, Sendable {
    case left
    case right
}

/// Posts synthetic mouse events: pointer move first, then a down/up pair
/// with `mouseEventClickState` set and no modifier flags attached (whatever
/// the user is physically holding), at the HID tap location so events behave
/// like physical clicks in every app.
struct ClickSynthesizer {
    /// Stamped into `eventSourceUserData` of every synthesized event so the
    /// event tap can tell our clicks apart from physical mouse input (which
    /// dismisses the session).
    static let eventSignature: Int64 = 0x5347_5249 // "SGRI"

    private let source: CGEventSource?

    init() {
        source = CGEventSource(stateID: .hidSystemState)
        source?.userData = Self.eventSignature
    }

    /// Moves the pointer, then posts the click. `clickState` is 1 for a
    /// single click, 2/3 for double/triple upgrades.
    func postClick(at point: CGPoint, button: MouseButton, clickState: Int64) {
        movePointer(to: point)

        let (downType, upType, cgButton): (CGEventType, CGEventType, CGMouseButton) =
            switch button {
            case .left: (.leftMouseDown, .leftMouseUp, .left)
            case .right: (.rightMouseDown, .rightMouseUp, .right)
            }

        for type in [downType, upType] {
            guard let event = CGEvent(
                mouseEventSource: source,
                mouseType: type,
                mouseCursorPosition: point,
                mouseButton: cgButton
            ) else { continue }
            event.setIntegerValueField(.mouseEventClickState, value: clickState)
            event.flags = [] // synthesized events carry no modifiers
            event.post(tap: .cghidEventTap)
        }
    }

    /// Posts one continuous (pixel-unit) scroll wheel tick; it lands on
    /// whatever is under the pointer. Positive deltas scroll up, negative
    /// down.
    func postScroll(pixels: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 1,
            wheel1: pixels,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        // Continuous (trackpad-style) events glide instead of stepping in
        // wheel notches.
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    /// Warps the pointer via a posted `mouseMoved` event so hover states
    /// resolve before the click; also used by nudge mode.
    func movePointer(to point: CGPoint) {
        guard let move = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        move.flags = []
        move.post(tap: .cghidEventTap)
    }
}
