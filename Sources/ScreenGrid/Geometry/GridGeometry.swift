import AppKit
import CoreGraphics

/// Pure geometry for one session's target screen: the 10-column × 30-row
/// cell lattice (two-letter cell selection) and the 10×3 fine sub-grid
/// inside a cell.
///
/// All frames and points are in **global Quartz coordinates** — origin at
/// the top-left of the primary display, y growing downward — which is what
/// `CGEvent` expects.
struct GridGeometry: Equatable, Sendable {
    static let columnCount = 10
    static let rowCount = 30
    static let fineColumnCount = 10
    static let fineRowCount = 3

    /// Target screen frame in global Quartz coordinates.
    let screenFrame: CGRect
    /// Per-screen scale factor, kept for pixel-alignment of hairlines.
    let backingScaleFactor: CGFloat

    init(screenFrame: CGRect, backingScaleFactor: CGFloat = 2) {
        self.screenFrame = screenFrame
        self.backingScaleFactor = backingScaleFactor
    }

    /// Builds geometry for an `NSScreen`, converting its AppKit
    /// (bottom-left-origin) frame into global Quartz coordinates.
    @MainActor
    init(screen: NSScreen) {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let frame = screen.frame
        self.init(
            screenFrame: CGRect(
                x: frame.origin.x,
                y: primaryHeight - frame.maxY,
                width: frame.width,
                height: frame.height
            ),
            backingScaleFactor: screen.backingScaleFactor
        )
    }

    // MARK: Cell selection — columns, rows, cells

    /// Frame of vertical column `column` (0 = leftmost = `A`).
    func columnFrame(_ column: Int) -> CGRect {
        gridRect(column: column, columnCount: Self.columnCount, row: 0, rowCount: 1)
    }

    /// Frame of the cell at (`column`, `row`); row 0 is the top (`Q`).
    /// E.g. `G K` → column 4, row 17 → exactly (4/10·W, 17/30·H, W/10, H/30).
    func cellFrame(column: Int, row: Int) -> CGRect {
        gridRect(column: column, columnCount: Self.columnCount, row: row, rowCount: Self.rowCount)
    }

    func cellCenter(column: Int, row: Int) -> CGPoint {
        center(of: cellFrame(column: column, row: row))
    }

    // MARK: Fine grid

    /// Frame of a sub-region inside a cell. `fineColumn` 0–9 left to right,
    /// `fineRow` 0–2 top to bottom (Q row, A row, Z row). Each sub-region is
    /// 1/100 of the screen width × 1/90 of its height.
    func subRegionFrame(column: Int, row: Int, fineColumn: Int, fineRow: Int) -> CGRect {
        let cell = cellFrame(column: column, row: row)
        let width = cell.width / CGFloat(Self.fineColumnCount)
        let height = cell.height / CGFloat(Self.fineRowCount)
        return CGRect(
            x: cell.minX + CGFloat(fineColumn) * width,
            y: cell.minY + CGFloat(fineRow) * height,
            width: width,
            height: height
        )
    }

    func subRegionCenter(column: Int, row: Int, fineColumn: Int, fineRow: Int) -> CGPoint {
        center(of: subRegionFrame(column: column, row: row, fineColumn: fineColumn, fineRow: fineRow))
    }

    // MARK: Pointer confinement

    /// Confines a point to the screen frame so nudge/free motion stops at the
    /// edges instead of roaming onto an adjacent display.
    func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, screenFrame.minX), screenFrame.maxX),
            y: min(max(point.y, screenFrame.minY), screenFrame.maxY)
        )
    }

    // MARK: Helpers

    /// Multiplies before dividing so grid lines land exactly (7/10 of 1440
    /// must be 1008, not 1007.999…) — selected-cell frames are contractual.
    private func gridRect(column: Int, columnCount: Int, row: Int, rowCount: Int) -> CGRect {
        CGRect(
            x: screenFrame.minX + screenFrame.width * CGFloat(column) / CGFloat(columnCount),
            y: screenFrame.minY + screenFrame.height * CGFloat(row) / CGFloat(rowCount),
            width: screenFrame.width / CGFloat(columnCount),
            height: screenFrame.height / CGFloat(rowCount)
        )
    }

    private func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }
}
