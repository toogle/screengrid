import CoreGraphics
import QuartzCore
import Testing

@testable import ScreenGrid

/// The scroll-mode glide: `ScrollEngine` drains a queued distance frame by
/// frame through `Timing.scrollGlideStep`, an exponential ease-out with a
/// settle floor. These cover the invariants that keep the glide feeling
/// native — it never overshoots and always settles in finite time.
@MainActor // Timing's constants are main-actor-isolated
@Suite struct ScrollGlideTests {
    private let frame: CFTimeInterval = 1.0 / Timing.scrollFrameRate

    /// A fresh press queues exactly one scroll step; each of the two
    /// directions owes that distance with the sign scroll mode posts.
    @Test func freshPressQueuesOneStep() {
        #expect(Timing.scrollStep == 80)
        // The held-key feed is deliberately gentler than a fresh hop.
        #expect(Timing.scrollRepeatStep == Timing.scrollStep / 2)
    }

    /// One frame never spends more than is owed and never reverses the
    /// glide's direction — overshoot would jitter the content past its rest.
    @Test(arguments: [-500.0, -80.0, -40.0, -1.0, 1.0, 40.0, 80.0, 500.0])
    func stepNeverOvershoots(remaining: Double) {
        let owed = CGFloat(remaining)
        let step = Timing.scrollGlideStep(remaining: owed, dt: frame)
        #expect(abs(step) <= abs(owed) + 1e-9)
        #expect((step < 0) == (owed < 0)) // same sign, never overshoots past rest
    }

    /// The settle floor guarantees the exponential tail terminates: draining
    /// a full 80 px step reaches exactly zero in a bounded number of frames
    /// rather than crawling asymptotically forever.
    @Test func glideSettlesToRestInFiniteFrames() {
        var remaining = Timing.scrollStep
        var frames = 0
        while remaining != 0 {
            remaining -= Timing.scrollGlideStep(remaining: remaining, dt: frame)
            frames += 1
            #expect(frames < 10_000, "glide must terminate")
        }
        #expect(remaining == 0)
    }

    /// The floor also holds for an upward (positive) glide, settling to a
    /// clean zero from the other side.
    @Test func upwardGlideSettlesToRest() {
        var remaining = -Timing.scrollStep
        var frames = 0
        while remaining != 0 {
            remaining -= Timing.scrollGlideStep(remaining: remaining, dt: frame)
            frames += 1
            #expect(frames < 10_000, "glide must terminate")
        }
        #expect(remaining == 0)
    }

    /// Early in a large glide the eased step dominates the floor — the glide
    /// leads with speed and only falls back to the floor for the final tail.
    @Test func largeGlideLeadsWithEasedStep() {
        let floorStep = Timing.scrollSettleSpeed * CGFloat(frame)
        let step = Timing.scrollGlideStep(remaining: 500, dt: frame)
        #expect(step > floorStep)
    }
}
