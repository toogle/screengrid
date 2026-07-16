import AppKit
import Carbon
import CoreGraphics
import QuartzCore

/// The single owner of the interaction state machine, tap callbacks, and
/// timers. Everything runs on the main actor: the event tap's run-loop
/// source is on the main run loop, so consume/pass decisions stay
/// synchronous while UI updates happen in the same isolation domain.
@MainActor
final class SessionController {
    private let eventTap = EventTapManager()
    private let tapDetector = CommandTapDetector()
    private let overlay = OverlayWindowController()
    private let clicker = ClickSynthesizer()
    private let scrollEngine = ScrollEngine()

    private(set) var phase: SessionPhase = .idle {
        didSet { overlay.model.phase = phase }
    }

    /// Geometry of the screen the current session targets; nil while idle.
    private var geometry: GridGeometry?

    /// Arrow keys physically held right now, tracked across keyDown/keyUp.
    /// Movement in nudge/free mode is driven by this set, not by key
    /// auto-repeat: macOS repeats only the most recently pressed key and
    /// stalls on every fresh press, which would freeze the pointer whenever
    /// the user changes direction.
    private var heldArrows: Set<CGKeyCode> = []

    /// Live Shift state, tracked from the flags every tapped keyboard event
    /// carries. `NSEvent.modifierFlags` cannot be trusted mid-session: the
    /// tap consumes keyboard events before the app's event stream sees
    /// them, so it goes stale — a glide would miss the held Shift and run
    /// at full speed instead of the fine pace.
    private var shiftHeld = false

    /// Frame timer driving the held-arrow glide, with the timestamps its
    /// ease-in ramp and per-frame deltas are measured from.
    private var glideTimer: Timer?
    private var glideStart: CFTimeInterval = 0
    private var glideLastTick: CFTimeInterval = 0

    /// The scroll key currently held, feeding the scroll glide; its keyUp
    /// ends the feed.
    private var heldScrollKey: CGKeyCode?

    private var multiClickTimer: Timer?

    /// Observers that force-dismiss the session when the overlay loses
    /// screen availability: display reconfiguration, screen lock, and fast
    /// user switch. Each token is paired with the center it came from.
    private var dismissalObservers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    private(set) var isEnabled = false

    /// True while the system has the event tap disabled (usually a revoked
    /// permission) and automatic re-enabling did not stick.
    private(set) var isTapBroken = false

    /// Fired when `isTapBroken` flips, so the menu bar icon can update.
    var onHealthChange: (() -> Void)?

    // MARK: Lifecycle

    init() {
        scrollEngine.post = { [clicker] in clicker.postScroll(pixels: $0) }
    }

    func enable() {
        guard !isEnabled else { return }
        eventTap.handler = { [weak self] event, type in
            self?.handle(event: event, type: type) ?? .pass
        }
        eventTap.onTapDisabled = { [weak self] recovered in
            guard let self else { return }
            self.endSession()
            self.setTapBroken(!recovered)
        }
        tapDetector.onTap = { [weak self] in
            self?.toggleSession()
        }
        do {
            try eventTap.start()
            isEnabled = true
            setTapBroken(false)
        } catch {
            NSLog("SessionController: failed to start event tap: \(error)")
            setTapBroken(true)
        }
        installDismissalObservers()
    }

    func disable() {
        endSession()
        removeDismissalObservers()
        eventTap.stop()
        tapDetector.reset()
        isEnabled = false
    }

    /// Secure input engaged while a session was live (a password prompt
    /// appeared, or the frontmost app grabbed secure keyboard entry):
    /// keyDowns no longer reach the tap, so the overlay is dead — dismiss
    /// it before more keystrokes leak into the focused app.
    func secureInputDidActivate() {
        guard phase != .idle else { return }
        endSession()
    }

    private func setTapBroken(_ broken: Bool) {
        guard isTapBroken != broken else { return }
        isTapBroken = broken
        onHealthChange?()
    }

    // MARK: Event routing

    private func handle(event: CGEvent, type: CGEventType) -> EventTapManager.Verdict {
        let isMouseEvent = switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel: true
        default: false
        }

        // Our own synthesized clicks come back through the tap; they must
        // not be mistaken for physical mouse input ending the session.
        if isMouseEvent,
            event.getIntegerValueField(.eventSourceUserData) == ClickSynthesizer.eventSignature
        {
            return .pass
        }

        if !isMouseEvent {
            shiftHeld = event.flags.contains(.maskShift)
        }

        if phase == .idle {
            tapDetector.handle(event: event, type: type)
            return .pass
        }

        if isMouseEvent {
            // Physical mouse activity dismisses the session — and still
            // reaches the apps.
            endSession()
            return .pass
        }

        // The detector keeps running in every phase: a left-⌘ tap toggles
        // the overlay away, and any key pressed mid-⌘-hold rejects the
        // pending tap exactly as it does while idle — ⌘C with the overlay up
        // is a shortcut, not a tap.
        tapDetector.handle(event: event, type: type)

        // While a session is active *all* keyboard events are consumed so no
        // stray characters leak into the focused application.
        if type == .keyUp {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            heldArrows.remove(keyCode)
            if heldArrows.isEmpty {
                cancelGlide()
            }
            if keyCode == heldScrollKey {
                heldScrollKey = nil
                scrollEngine.endSustain()
            }
        }
        if type == .keyDown {
            handleKeyDown(event)
        }
        return .consume
    }

    private func handleKeyDown(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let controlHeld = event.flags.contains(.maskControl)

        if Keys.arrows.contains(keyCode) {
            heldArrows.insert(keyCode) // matching keyUp removes it
        }

        // Auto-repeat is ignored outright: holding a letter or Space must
        // not double-click, and held-key motion — nudge/free glides and
        // scroll-mode feeding — runs off frame timers over the held-key
        // state instead. Auto-repeat follows only the newest key and pauses
        // its initial delay after every fresh press, which would freeze the
        // motion on each direction change and after the first hop.
        if isAutorepeat {
            return
        }

        // During the multi-click window every key is judged against the
        // click key: a match upgrades the click, anything else ends the
        // session without reaching the frontmost app.
        if case .multiClick(let state) = phase {
            handleMultiClickKey(keyCode, state: state, controlHeld: controlHeld)
            return
        }

        // Scroll mode: `,`/`.` keep scrolling, arrows hand off to free mode;
        // any other key — Escape and Backspace included — ends the session.
        if case .scroll(_, let point) = phase {
            handleScrollKey(keyCode, point: point, shiftHeld: shiftHeld)
            return
        }

        // Nudge/free mode: arrows keep steering, `,`/`.` hand off to scroll
        // mode, Space/Return clicks; any other key — Escape and Backspace
        // included — ends the session.
        if case .nudge(let point) = phase {
            handleNudgeKey(keyCode, point: point, controlHeld: controlHeld, shiftHeld: shiftHeld)
            return
        }

        // Escape always dismisses; Backspace steps back one stage.
        if keyCode == Keys.escape {
            endSession()
            return
        }
        if keyCode == Keys.backspace {
            stepBack()
            return
        }

        switch phase {
        case .idle, .multiClick, .scroll, .nudge: // scroll and nudge are routed above
            break
        case .columns:
            handleColumnsKey(keyCode, shiftHeld: shiftHeld)
        case .rows(let column):
            handleRowsKey(keyCode, column: column)
        case .fineGrid(let column, let row):
            handleFineGridKey(keyCode, column: column, row: row, controlHeld: controlHeld)
        }
    }

    // MARK: Stage handlers

    private func handleColumnsKey(_ keyCode: CGKeyCode, shiftHeld: Bool) {
        if Keys.arrows.contains(keyCode) {
            // Enter free mode: nudge from wherever the pointer already sits,
            // no cell involved — the entering press already steps.
            nudgePointer(from: pointerLocation, shiftHeld: shiftHeld)
            return
        }
        if let direction = ScrollDirection(keyCode: keyCode) {
            // Enter scroll mode: the grid hides behind a direction badge at
            // the pointer, the press that entered already scrolls, and
            // holding the key keeps feeding the glide.
            enterScrollMode(direction: direction, at: pointerLocation, keyCode: keyCode)
            return
        }
        guard let column = Keys.homeRowIndex(of: keyCode) else { return } // swallowed
        phase = .rows(column: column)
    }

    private func handleRowsKey(_ keyCode: CGKeyCode, column: Int) {
        // The second letter of the cell code — any of the 30 QWERTY-block keys.
        guard let row = Keys.qwertyRowIndex(of: keyCode) else { return }
        phase = .fineGrid(column: column, row: row)
    }

    private func handleFineGridKey(_ keyCode: CGKeyCode, column: Int, row: Int, controlHeld: Bool) {
        guard let geometry else { return }

        if Keys.arrows.contains(keyCode) {
            // Enter nudge mode: pointer warps to the cell center. Holding
            // the arrow glides from there.
            let center = geometry.cellCenter(column: column, row: row)
            clicker.movePointer(to: center)
            phase = .nudge(point: center)
            startGlide()
            return
        }

        if keyCode == Keys.space {
            // "Close enough, click here" — the exact cell center.
            click(at: geometry.cellCenter(column: column, row: row), keyCode: keyCode, controlHeld: controlHeld)
            return
        }

        if let (fineRow, fineColumn) = Keys.fineGridPosition(of: keyCode) {
            let target = geometry.subRegionCenter(
                column: column, row: row,
                fineColumn: fineColumn, fineRow: fineRow
            )
            click(at: target, keyCode: keyCode, controlHeld: controlHeld)
        }
        // Anything else: swallowed and ignored.
    }

    /// Nudge/free mode: arrows keep steering — a held vertical + horizontal
    /// pair diagonally, Shift dropping to fine 1 pt motion — and
    /// Space/Return clicks. A **scroll key** (`,`/`.`) hands off to scroll
    /// mode at the cursor: the two modes are interchangeable. Any other key
    /// ends the session, consumed like every session key.
    private func handleNudgeKey(_ keyCode: CGKeyCode, point: CGPoint, controlHeld: Bool, shiftHeld: Bool) {
        if Keys.arrows.contains(keyCode) {
            nudgePointer(from: point, shiftHeld: shiftHeld)
            return
        }

        if let direction = ScrollDirection(keyCode: keyCode) {
            // Hand off to scroll mode at the cursor: the pointer glide stops
            // and the entering press already scrolls what sits under it.
            cancelGlide()
            enterScrollMode(direction: direction, at: point, keyCode: keyCode)
            return
        }

        if keyCode == Keys.space || keyCode == Keys.returnKey {
            click(at: point, keyCode: keyCode, controlHeld: controlHeld)
            return
        }

        endSession()
    }

    /// Moves the pointer one nudge step (a fine 1 pt with Shift held) along
    /// the unit direction of every held arrow combined — a vertical +
    /// horizontal pair steps diagonally, covering the same distance as a
    /// straight step — settles into nudge mode, and arms the glide that
    /// takes over while arrows stay down. Fresh presses only; repeats are
    /// filtered before reaching here.
    private func nudgePointer(from point: CGPoint, shiftHeld: Bool) {
        let vector = Keys.combinedArrowVector(of: heldArrows)
        let step = shiftHeld ? Timing.nudgeFineStep : Timing.nudgeStep
        // The pointer is clamped to the overlay's screen — it never rides
        // past an edge onto another display, keeping the cursor where the
        // grid lives.
        let next = clampToScreen(CGPoint(x: point.x + vector.dx * step, y: point.y + vector.dy * step))
        clicker.movePointer(to: next)
        phase = .nudge(point: next)
        startGlide()
    }

    /// Confines a point to the overlay's screen so nudge/free motion stops at
    /// the edges instead of roaming onto adjacent displays. With no geometry
    /// (never the case in these modes) the point passes through.
    private func clampToScreen(_ point: CGPoint) -> CGPoint {
        geometry?.clamp(point) ?? point
    }

    /// The pointer's current global (Quartz) position, where free and scroll
    /// mode begin when entered from stage 1.
    private var pointerLocation: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    // MARK: Nudge glide

    /// Starts the held-arrow glide the instant an arrow goes down, easing
    /// in from rest (`Timing.glideRamp`) so a hold accelerates straight out
    /// of its first step with no auto-repeat-style pause — while a quick
    /// tap stays step-precise, because the ramp has barely moved by the
    /// time the key lifts and the keyUp cancels the glide. A press landing
    /// mid-glide just steps and steers; the ramp never restarts while the
    /// glide runs.
    private func startGlide() {
        guard glideTimer == nil, !heldArrows.isEmpty else { return }
        glideStart = CACurrentMediaTime()
        glideLastTick = glideStart
        glideTimer = .mainRunLoopFrames(hz: Timing.nudgeFrameRate) { [weak self] in
            self?.glideFrame()
        }
    }

    /// One glide frame: move along the unit direction of every held arrow
    /// combined — diagonals run at the same pace as straight glides — at
    /// the key-repeat speed, eased in from the glide's start. Direction and
    /// Shift (fine 1 pt pace) are sampled every frame, so pressing or
    /// releasing keys mid-glide steers and re-paces instantly instead of
    /// stalling like key auto-repeat — Shift-fine motion stays fine through
    /// every direction change.
    private func glideFrame() {
        guard case .nudge(let point) = phase, !heldArrows.isEmpty else {
            cancelGlide() // clicked away or left the mode with arrows down
            return
        }
        let now = CACurrentMediaTime()
        // Clamp stalls (a blocked run loop) so the glide resumes instead of
        // jumping.
        let dt = CGFloat(min(now - glideLastTick, 0.1))
        glideLastTick = now

        let vector = Keys.combinedArrowVector(of: heldArrows)
        let speed = (shiftHeld
            ? Timing.nudgeFineGlideSpeed
            : Timing.nudgeGlideSpeed) * Timing.glideRamp(age: now - glideStart)
        let next = clampToScreen(CGPoint(
            x: point.x + vector.dx * speed * dt,
            y: point.y + vector.dy * speed * dt
        ))
        clicker.movePointer(to: next)
        phase = .nudge(point: next)
    }

    private func cancelGlide() {
        glideTimer?.invalidate()
        glideTimer = nil
    }

    /// Scroll mode: `,` and `.` scroll one step per press and keep feeding
    /// the glide while held. An **arrow** hands off to free mode at the
    /// cursor: the two modes are interchangeable. Any other key ends the
    /// session, consumed like every session key.
    private func handleScrollKey(_ keyCode: CGKeyCode, point: CGPoint, shiftHeld: Bool) {
        if Keys.arrows.contains(keyCode) {
            // Hand off to free mode from the badge position: the scroll glide
            // stops and the entering arrow already steps the pointer.
            heldScrollKey = nil
            scrollEngine.cancel() // drops the queued glide and its held-key feed
            nudgePointer(from: point, shiftHeld: shiftHeld)
            return
        }

        guard let direction = ScrollDirection(keyCode: keyCode) else {
            endSession()
            return
        }
        enterScrollMode(direction: direction, at: point, keyCode: keyCode)
    }

    /// Enters (or, from within scroll mode, re-arms) scroll mode at `point`:
    /// the entering press scrolls one step and the held key feeds the glide.
    /// The single path every scroll-mode entry — stage 1, nudge/free handoff,
    /// and a fresh `,`/`.` while already scrolling — funnels through.
    private func enterScrollMode(direction: ScrollDirection, at point: CGPoint, keyCode: CGKeyCode) {
        phase = .scroll(direction: direction, point: point)
        postScrollStep(direction)
        beginScrollSustain(keyCode)
    }

    private func handleMultiClickKey(_ keyCode: CGKeyCode, state: MultiClickState, controlHeld: Bool) {
        let button: MouseButton = controlHeld ? .right : .left
        guard keyCode == state.keyCode, button == state.button, state.clickCount < 3 else {
            // Different key or ⌃-state mismatch ends the session; the key is
            // part of the interaction and is not forwarded to the app.
            endSession()
            return
        }
        var next = state
        next.clickCount += 1
        clicker.postClick(at: state.point, button: state.button, clickState: next.clickCount)
        phase = .multiClick(next)
        restartMultiClickTimer()
    }

    // MARK: Clicking

    /// Posts the first click immediately (never delayed waiting for a
    /// possible repeat) and opens the multi-click window. ⌃ at the instant
    /// of the keypress turns the click into a right click.
    private func click(at point: CGPoint, keyCode: CGKeyCode, controlHeld: Bool) {
        let button: MouseButton = controlHeld ? .right : .left
        clicker.postClick(at: point, button: button, clickState: 1)

        // The overlay starts dismissing while key capture stays open for
        // double/triple-click upgrades.
        overlay.hide()
        phase = .multiClick(MultiClickState(keyCode: keyCode, button: button, point: point, clickCount: 1))
        restartMultiClickTimer()
    }

    private func restartMultiClickTimer() {
        multiClickTimer?.invalidate()
        multiClickTimer = Timer.scheduledTimer(withTimeInterval: Timing.multiClickWindow, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { // scheduled on the main run loop
                self?.endSession()
            }
        }
    }

    // MARK: Scrolling

    /// Queues one fresh-press scroll step under the pointer. The engine
    /// glides the distance out in small eased frames instead of one jump.
    /// Positive deltas scroll up.
    private func postScrollStep(_ direction: ScrollDirection) {
        let pixels = Timing.scrollStep
        scrollEngine.add(pixels: direction == .up ? pixels : -pixels)
    }

    /// Feeds the scroll glide for as long as the key stays down — the
    /// held-key replacement for auto-repeat: half the fresh-press distance
    /// per key-repeat interval, eased in from rest by the engine so the
    /// hold flows straight out of the first hop with no pause. Direction is
    /// sampled per frame.
    private func beginScrollSustain(_ keyCode: CGKeyCode) {
        heldScrollKey = keyCode
        scrollEngine.beginSustain { [weak self] in
            self?.scrollSustainRate() ?? 0
        }
    }

    /// Current held-key feed rate in px/s (positive up); zero once the
    /// session has left scroll mode.
    private func scrollSustainRate() -> CGFloat {
        guard case .scroll(let direction, _) = phase else { return 0 }
        let pixels = Timing.scrollRepeatStep
        return (direction == .up ? pixels : -pixels) / CGFloat(NSEvent.keyRepeatInterval)
    }

    // MARK: Session lifecycle

    private func toggleSession() {
        if phase == .idle {
            beginSession()
        } else {
            endSession()
        }
    }

    private func beginSession() {
        // Secure input suppresses keyDown/keyUp for event taps while
        // flagsChanged still comes through — so the ⌘-tap fires, but every
        // keystroke would bypass the tap and leak into the focused app
        // (Chrome holds secure keyboard entry far more eagerly than Safari).
        // Refuse to open a dead overlay.
        guard !IsSecureEventInputEnabled() else { return }

        // The overlay appears on the screen currently containing the pointer
        // and covers it entirely, over full-screen apps and all Spaces.
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
            ?? NSScreen.main
        else { return }

        geometry = GridGeometry(screen: screen)
        overlay.model.geometry = geometry
        overlay.show(on: screen)
        phase = .columns
    }

    /// Ends the session immediately: the phase returns to idle before the
    /// overlay's out-animation finishes, so a fresh ⌘-tap can start a new
    /// session while the old overlay is still fading.
    private func endSession() {
        multiClickTimer?.invalidate()
        multiClickTimer = nil
        scrollEngine.cancel() // clears the held-key feed too
        cancelGlide()
        heldArrows = []
        heldScrollKey = nil
        overlay.hide()
        geometry = nil
        phase = .idle
        tapDetector.reset()
    }

    /// Backspace: fine grid → rows → columns; at stage 0 it is swallowed
    /// like any other invalid key. Scroll and nudge/free modes never reach
    /// here — any non-mode key there ends the session instead.
    private func stepBack() {
        switch phase {
        case .fineGrid(let column, _):
            phase = .rows(column: column)
        case .rows:
            phase = .columns
        case .columns, .idle, .multiClick, .scroll, .nudge:
            break
        }
    }

    // MARK: Forced dismissal

    private func installDismissalObservers() {
        let dismiss: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { // observers below are queued on .main
                self?.endSession()
            }
        }

        let center = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let distributedCenter = DistributedNotificationCenter.default()

        dismissalObservers = [
            // Display reconfiguration: resolution change, screen unplugged.
            (center, center.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main, using: dismiss
            )),
            // Fast user switch.
            (workspaceCenter, workspaceCenter.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification,
                object: nil, queue: .main, using: dismiss
            )),
            // Screen lock.
            (distributedCenter, distributedCenter.addObserver(
                forName: Notification.Name("com.apple.screenIsLocked"),
                object: nil, queue: .main, using: dismiss
            )),
        ]
    }

    private func removeDismissalObservers() {
        for (center, token) in dismissalObservers {
            center.removeObserver(token)
        }
        dismissalObservers = []
    }
}
