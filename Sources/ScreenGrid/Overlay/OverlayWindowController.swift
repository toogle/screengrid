import AppKit
import SwiftUI

/// Hosts the overlay: a borderless, non-activating `NSPanel` at screen-saver
/// level that joins all Spaces and floats over full-screen apps. The panel
/// never takes key focus — input comes exclusively from the event tap — and
/// ignores mouse events entirely; it is a display surface only.
@MainActor
final class OverlayWindowController {
    let model = OverlayModel()

    private var panel: NSPanel?

    func show(on screen: NSScreen) {
        hide(animated: false)

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        panel.contentView = NSHostingView(rootView: OverlayRootView(model: model))
        panel.setFrame(screen.frame, display: true)

        // Fade in; the animation is asynchronous, so a fast typist's first
        // keystroke is handled before the fade completes.
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Timing.overlayShowHide
            panel.animator().alphaValue = 1
        }

        self.panel = panel
    }

    /// Fades out and releases the panel. The controller forgets the panel
    /// immediately, so a fresh session can show a new overlay while the old
    /// one is still animating out.
    func hide(animated: Bool = true) {
        guard let panel else { return }
        self.panel = nil

        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Timing.overlayShowHide
            panel.animator().alphaValue = 0
        }, completionHandler: {
            // The completion fires on the main thread.
            MainActor.assumeIsolated {
                panel.orderOut(nil)
            }
        })
    }
}
