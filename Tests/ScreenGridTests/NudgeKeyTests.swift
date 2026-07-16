import AppKit
import CoreGraphics
import Testing

@testable import ScreenGrid

/// Arrow-key handling shared by nudge mode (entered from a chosen cell) and
/// free mode (entered from the full stage-1 grid).
@MainActor // Timing's constants are main-actor-isolated
@Suite struct NudgeKeyTests {
    /// Arrows steer in Quartz coordinates: y grows downward, so ↑ must
    /// carry a negative dy — flipping this clicks above the target instead
    /// of below.
    @Test func arrowVectorsUseQuartzCoordinates() {
        #expect(Keys.arrowVector(of: Keys.arrowLeft) == CGVector(dx: -1, dy: 0))
        #expect(Keys.arrowVector(of: Keys.arrowRight) == CGVector(dx: 1, dy: 0))
        #expect(Keys.arrowVector(of: Keys.arrowUp) == CGVector(dx: 0, dy: -1))
        #expect(Keys.arrowVector(of: Keys.arrowDown) == CGVector(dx: 0, dy: 1))
    }

    /// Every key in `Keys.arrows` has a vector and nothing else does — the
    /// set that routes a key into nudge/free mode and the table that moves
    /// the pointer must never drift apart.
    @Test func arrowSetMatchesVectorTable() {
        #expect(Keys.arrows.count == 4)
        for code in Keys.arrows {
            #expect(Keys.arrowVector(of: code) != nil)
        }
        for code in [Keys.space, Keys.returnKey, Keys.escape, Keys.backspace, Keys.comma] {
            #expect(Keys.arrowVector(of: code) == nil)
        }
    }

    /// Arrow key codes collide with no key any stage consumes first — home
    /// row, QWERTY block, Space/Return, Escape/Backspace, scroll keys — so
    /// an arrow can only mean free mode at stage 1 and nudge mode at stage 2.
    @Test func arrowsAreDistinctFromStageKeys() {
        let stageKeys = Set(Keys.qwertyRows + Keys.homeRow)
            .union([Keys.space, Keys.returnKey, Keys.escape, Keys.backspace, Keys.comma, Keys.period])
        #expect(Keys.arrows.isDisjoint(with: stageKeys))
    }

    /// A vertical and a horizontal arrow held together steer diagonally at
    /// unit length — the same pace as a single arrow, not √2× faster;
    /// opposite arrows cancel; non-arrow keys held alongside contribute
    /// nothing.
    @Test func heldArrowsCombineIntoDiagonals() {
        let diagonal = Keys.combinedArrowVector(of: [Keys.arrowRight, Keys.arrowDown])
        #expect(diagonal.dx == diagonal.dy)
        #expect(diagonal.dx > 0)
        #expect(Keys.combinedArrowVector(of: [Keys.arrowLeft, Keys.arrowUp])
            == CGVector(dx: -diagonal.dx, dy: -diagonal.dy))
        #expect(Keys.combinedArrowVector(of: [Keys.arrowLeft, Keys.arrowRight]) == CGVector.zero)
        #expect(Keys.combinedArrowVector(of: [Keys.arrowUp]) == Keys.arrowVector(of: Keys.arrowUp))
        #expect(Keys.combinedArrowVector(of: [Keys.arrowUp, Keys.space]) == Keys.arrowVector(of: Keys.arrowUp))
        #expect(Keys.combinedArrowVector(of: []) == CGVector.zero)
    }

    /// The steering direction is unit-length for every non-cancelling hold —
    /// each single arrow and all four diagonals — so the glide and the
    /// discrete step keep one constant pace regardless of direction or how
    /// many arrows are down. Without normalization a diagonal would run √2×
    /// too fast.
    @Test func steeringDirectionStaysUnitLength() {
        let diagonals: [Set<CGKeyCode>] = [
            [Keys.arrowRight, Keys.arrowUp], [Keys.arrowRight, Keys.arrowDown],
            [Keys.arrowLeft, Keys.arrowUp], [Keys.arrowLeft, Keys.arrowDown],
        ]
        for held in Keys.arrows.map({ [$0] }) + diagonals {
            let vector = Keys.combinedArrowVector(of: held)
            let length = (vector.dx * vector.dx + vector.dy * vector.dy).squareRoot()
            #expect(abs(length - 1) < 1e-12)
        }
    }

    /// Nudge/free mode and scroll mode are interchangeable: an arrow hands
    /// scroll mode off to free mode, and `,`/`.` hand nudge/free mode off to
    /// scroll mode. Each handoff key must be unambiguously the other mode's
    /// trigger — every arrow steers and is never a scroll direction, and
    /// `,`/`.` are scroll directions and never arrows.
    @Test func modeHandoffKeysAreUnambiguous() {
        for arrow in Keys.arrows {
            #expect(ScrollDirection(keyCode: arrow) == nil)
        }
        #expect(ScrollDirection(keyCode: Keys.comma) == .down)
        #expect(ScrollDirection(keyCode: Keys.period) == .up)
        #expect(Keys.arrowVector(of: Keys.comma) == nil)
        #expect(Keys.arrowVector(of: Keys.period) == nil)
    }

    /// Acceptance 7/12: ten `→` presses move the pointer exactly 100 pt
    /// right, and the Shift step is a fine single point in both nudge and
    /// free mode.
    @Test func stepsMatchAcceptanceCriteria() {
        let right = Keys.arrowVector(of: Keys.arrowRight)!
        #expect(10 * Timing.nudgeStep * right.dx == 100)

        #expect(Timing.nudgeFineStep == 1)
    }

    /// The glide replaces key auto-repeat, so it must pace like it: one
    /// step per key repeat interval — a fine point with Shift, mirroring
    /// the step ratio.
    @Test func glidePacingFollowsKeyRepeatSettings() {
        #expect(Timing.nudgeGlideSpeed == Timing.nudgeStep / CGFloat(NSEvent.keyRepeatInterval))
        #expect(Timing.nudgeFineGlideSpeed == Timing.nudgeFineStep / CGFloat(NSEvent.keyRepeatInterval))
    }

    /// The ease-in ramp lets a hold accelerate straight out of its first
    /// step — no auto-repeat-style pause — while keeping quick taps
    /// step-precise: it starts at rest, reaches full speed at the ramp
    /// duration, and grows quadratically in between, so a 100 ms tap adds
    /// only ~1 pt beyond its discrete step.
    @Test func glideRampEasesInFromRest() {
        #expect(Timing.glideRamp(age: 0) == 0)
        #expect(Timing.glideRamp(age: -1) == 0) // clock skew never reverses
        #expect(Timing.glideRamp(age: Timing.glideRampDuration / 2) == 0.25)
        #expect(Timing.glideRamp(age: Timing.glideRampDuration) == 1)
        #expect(Timing.glideRamp(age: 10) == 1)
    }
}
