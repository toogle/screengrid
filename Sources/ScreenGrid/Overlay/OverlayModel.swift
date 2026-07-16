import CoreGraphics
import Observation

/// Bridges the session state machine to the SwiftUI overlay content. The
/// controller writes; the stage views observe.
@MainActor
@Observable
final class OverlayModel {
    var phase: SessionPhase = .idle
    var geometry: GridGeometry?

    /// Pointer position for the nudge-mode crosshair ring, in the overlay
    /// view's local coordinates (derived from the phase's global point).
    var nudgePointInView: CGPoint? {
        guard case .nudge(let point) = phase else { return nil }
        return localPoint(from: point)
    }

    /// Pointer position for the scroll-mode direction badge, in the overlay
    /// view's local coordinates.
    var scrollPointInView: CGPoint? {
        guard case .scroll(_, let point) = phase else { return nil }
        return localPoint(from: point)
    }

    private func localPoint(from global: CGPoint) -> CGPoint? {
        guard let geometry else { return nil }
        return CGPoint(
            x: global.x - geometry.screenFrame.minX,
            y: global.y - geometry.screenFrame.minY
        )
    }
}
