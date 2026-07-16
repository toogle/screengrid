import AppKit

/// Timing constants for activation, animation, and the multi-click window.
@MainActor
enum Timing {
    /// Max press-to-release duration for the left-⌘ activation tap; slower
    /// presses are treated as held ⌘ (a shortcut in progress), not a tap.
    static let commandTapMaxDuration: TimeInterval = 0.200

    /// Multi-click upgrade window — follows the user's system double-click
    /// setting, so synthesized double/triple clicks feel native.
    static var multiClickWindow: TimeInterval { NSEvent.doubleClickInterval }

    /// Stage-change animation budget; animations never block input.
    static let stageTransition: TimeInterval = 0.120

    /// Overlay appear/dismiss animation budget; never blocks input.
    static let overlayShowHide: TimeInterval = 0.150

    /// Nudge/free mode pointer step per arrow press, in points.
    static let nudgeStep: CGFloat = 10
    /// Nudge/free mode step with Shift held — a single point, for
    /// pixel-precise placement.
    static let nudgeFineStep: CGFloat = 1

    /// Nudge/free mode glide speed, pt/s: one step per key repeat interval —
    /// the pace key auto-repeat used to deliver, made continuous and
    /// independent of which key the system chooses to repeat.
    static var nudgeGlideSpeed: CGFloat { nudgeStep / CGFloat(NSEvent.keyRepeatInterval) }
    /// Glide speed with Shift held — one point per repeat interval,
    /// matching the fine step.
    static var nudgeFineGlideSpeed: CGFloat { nudgeFineStep / CGFloat(NSEvent.keyRepeatInterval) }
    /// Tick rate of the nudge glide timer, in frames per second.
    static let nudgeFrameRate: Double = 120

    /// Hold-glide ease-in: time to accelerate from rest to full speed.
    /// Shared by the nudge glide and the held-key scroll feed, so motion
    /// starts the instant a key goes down — no auto-repeat-style pause
    /// after the first hop — while quick taps stay step-precise (a 100 ms
    /// tap glides only ~1 pt beyond its discrete step).
    static let glideRampDuration: TimeInterval = 0.3

    /// Quadratic ease-in factor `age` seconds into a hold: 0 at rest, 1
    /// from `glideRampDuration` on.
    static func glideRamp(age: TimeInterval) -> CGFloat {
        let t = min(max(age / glideRampDuration, 0), 1)
        return CGFloat(t * t)
    }

    /// Scroll mode distance per fresh `,`/`.` press, in pixels.
    static let scrollStep: CGFloat = 80
    /// Held-key scroll feed per key repeat interval — half a fresh press,
    /// so the sustained glide runs calmer than the first hop.
    static let scrollRepeatStep: CGFloat = 40

    /// Ease-out time constant of the scroll glide — how quickly a queued
    /// scroll distance is spent. Smaller is snappier, larger is floatier.
    static let scrollGlideTau: TimeInterval = 0.1
    /// Tick rate of the scroll glide timer, in frames per second.
    static let scrollFrameRate: Double = 120
    /// Speed floor for the glide's exponential tail, px/s, so every glide
    /// settles in finite time.
    static let scrollSettleSpeed: CGFloat = 80

    /// One eased frame of the scroll glide: the signed distance to spend this
    /// frame given the distance still owed (`remaining`, positive up) and the
    /// frame's duration. An exponential ease-out, with a speed floor so the
    /// tail settles crisply in finite time instead of crawling asymptotically.
    /// Never overshoots — the result shares `remaining`'s sign and its
    /// magnitude never exceeds `remaining`'s.
    static func scrollGlideStep(remaining: CGFloat, dt: CFTimeInterval) -> CGFloat {
        var step = remaining * (1 - CGFloat(exp(-dt / scrollGlideTau)))
        let floorStep = scrollSettleSpeed * CGFloat(dt)
        if abs(step) < floorStep {
            step = remaining < 0 ? max(remaining, -floorStep) : min(remaining, floorStep)
        }
        return step
    }
}

extension Timer {
    /// A scheduled, repeating frame timer on the **main** run loop in
    /// `.common` mode — so it keeps ticking through tracking run loops (a
    /// dragged slider, an open menu) instead of stalling. `hz` is frames per
    /// second; `body` runs on the main actor. Shared by the nudge glide and
    /// the scroll glide, which need identical scheduling.
    @MainActor
    static func mainRunLoopFrames(hz: Double, _ body: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: 1 / hz, repeats: true) { _ in
            MainActor.assumeIsolated { body() } // scheduled on the main run loop
        }
        timer.tolerance = 0.002
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
