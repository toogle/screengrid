import SwiftUI

/// Root SwiftUI content of the overlay panel; switches on the session phase
/// and renders the matching stage view.
///
/// The panel covers exactly the target screen, so view-local coordinates map
/// 1:1 onto the screen; stage views lay themselves out with plain fractions
/// and never need global geometry.
struct OverlayRootView: View {
    let model: OverlayModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch model.phase {
            case .idle, .multiClick:
                EmptyView()
            case .columns:
                ColumnsStageView()
            case .rows(let column):
                RowsStageView(column: column)
            case .fineGrid(let column, let row):
                FineGridStageView(column: column, row: row)
            case .nudge:
                NudgeStageView(pointerLocation: model.nudgePointInView)
            case .scroll(let direction, _):
                ScrollStageView(direction: direction, pointerLocation: model.scrollPointInView)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // Stage changes animate briefly and asynchronously — a fast typist's
        // keystrokes are all handled even mid-transition.
        .animation(stageAnimation, value: model.phase)
    }

    /// A short no-bounce spring, or a plain crossfade-friendly curve when
    /// Reduce Motion is on.
    private var stageAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: Timing.stageTransition)
            : .spring(duration: Timing.stageTransition, bounce: 0)
    }
}
