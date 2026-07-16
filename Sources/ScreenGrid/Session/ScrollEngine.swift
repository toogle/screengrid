import Foundation
import QuartzCore

/// Smooths scroll mode's output: each keypress deposits its distance here
/// instead of posting one wheel event directly, and a frame-rate timer
/// drains the balance with an exponential ease-out — a stream of small
/// continuous deltas that glides and settles like native macOS scrolling.
@MainActor
final class ScrollEngine {
    /// Posts one frame's pixel delta; positive scrolls up.
    var post: ((Int32) -> Void)?

    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0

    /// Signed distance still owed to the screen, in pixels; positive is up.
    private var remaining: CGFloat = 0

    /// Sub-pixel remainder carried between frames so slow glides don't
    /// lose distance to integer truncation.
    private var carry: CGFloat = 0

    /// Continuous feed while a scroll key is held — the held-key
    /// replacement for key auto-repeat. Sampled every frame (so direction
    /// and Shift changes apply live) and eased in from rest via
    /// `Timing.glideRamp`, so the hold flows straight out of the first hop
    /// with no auto-repeat-style pause. Signed px/s; positive is up.
    private var sustain: (() -> CGFloat)?
    private var sustainStart: CFTimeInterval = 0

    /// Queues a signed scroll distance (positive up). A press opposite to a
    /// pending glide cancels the glide first, so reversals respond
    /// immediately instead of fighting the leftover distance.
    func add(pixels: CGFloat) {
        if remaining != 0, (remaining < 0) != (pixels < 0) {
            remaining = 0
            carry = 0
        }
        remaining += pixels
        startTimer()
    }

    /// Starts (or retargets) the held-key feed. The ramp clock resets only
    /// when no feed was active, so direction or Shift changes mid-hold keep
    /// their full pace instead of easing in again.
    func beginSustain(_ rate: @escaping () -> CGFloat) {
        if sustain == nil {
            sustainStart = CACurrentMediaTime()
        }
        sustain = rate
        startTimer()
    }

    /// Stops the held-key feed; any distance already queued still settles.
    func endSustain() {
        sustain = nil
    }

    /// Drops any pending glide and feed; called when scroll mode ends.
    func cancel() {
        timer?.invalidate()
        timer = nil
        remaining = 0
        carry = 0
        sustain = nil
    }

    private func startTimer() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        timer = .mainRunLoopFrames(hz: Timing.scrollFrameRate) { [weak self] in
            self?.tick()
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        // Clamp stalls (a blocked run loop) so the glide resumes instead of
        // dumping the whole balance in one jump.
        let dt = min(now - lastTick, 0.1)
        lastTick = now

        // A held key deposits its distance continuously, ramped in from
        // rest so the hold accelerates out of the first hop.
        if let sustain {
            remaining += sustain() * Timing.glideRamp(age: now - sustainStart) * CGFloat(dt)
        }

        // Exponential ease-out, with a floor speed so the tail settles
        // crisply instead of asymptotically crawling.
        let step = Timing.scrollGlideStep(remaining: remaining, dt: dt)
        remaining -= step

        let exact = step + carry
        let whole = exact.rounded(.towardZero)
        carry = exact - whole
        if whole != 0 {
            post?(Int32(whole))
        }

        if remaining == 0, sustain == nil {
            timer?.invalidate()
            timer = nil
            carry = 0
        }
    }
}
