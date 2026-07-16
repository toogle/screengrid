import CoreGraphics

/// The interaction state machine:
/// `Idle → Columns (→ Nudge, → Scroll) → Rows → FineGrid (→ Nudge) → MultiClickWindow → Idle`.
enum SessionPhase: Equatable, Sendable {
    case idle

    /// First letter of the cell code pending — the full 10×30 grid of
    /// two-letter cells is shown; a home row key selects the column.
    case columns

    /// Second letter pending — the chosen column's 30 rows are labeled by
    /// the QWERTY block (`Q`…`/`, reading order); the rest of the screen dims.
    case rows(column: Int)

    /// Cell chosen — it is subdivided by the 10×3 QWERTY block; a key
    /// clicks its sub-region. `row` is 0–29.
    case fineGrid(column: Int, row: Int)

    /// Nudge/free mode — the grid hides, arrows steer the pointer directly
    /// (a held vertical + horizontal pair diagonally) until Space/Return
    /// clicks or any other key ends the session. Entered from a chosen cell
    /// (stage 2, pointer warped to its center) or from the full grid (free
    /// mode, stage 1, pointer left where it sits); behavior is identical
    /// either way. `point` is the current pointer position in global Quartz
    /// coordinates.
    case nudge(point: CGPoint)

    /// Scroll mode — the grid hides; every `,`/`.` press queues one scroll
    /// step under the pointer (auto-repeat glides) until any other key or a
    /// left-⌘ tap ends the session. `point` is the pointer position (global
    /// Quartz coordinates) captured on entry, where the direction badge renders.
    case scroll(direction: ScrollDirection, point: CGPoint)

    /// Overlay is dismissing but key capture stays active so a repeated key
    /// can upgrade the click to a double/triple click.
    case multiClick(MultiClickState)
}

/// Direction of continuous scrolling in scroll mode: `,` scrolls down,
/// `.` scrolls up.
enum ScrollDirection: Equatable, Sendable {
    case up
    case down

    /// The scroll direction a key selects, or nil for any non-scroll key.
    init?(keyCode: CGKeyCode) {
        switch keyCode {
        case Keys.comma: self = .down
        case Keys.period: self = .up
        default: return nil
        }
    }
}

/// State carried through the multi-click window.
struct MultiClickState: Equatable, Sendable {
    /// Key code that produced the click; only the same key repeats it.
    var keyCode: CGKeyCode
    /// Button of the original click; a ⌃-state mismatch (button mismatch)
    /// ends the session instead of upgrading.
    var button: MouseButton
    /// Where the click landed (global Quartz coordinates).
    var point: CGPoint
    /// 1 after the initial click, 2 after a double, 3 after a triple.
    var clickCount: Int64
}
