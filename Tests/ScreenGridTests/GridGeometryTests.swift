import CoreGraphics
import Testing

@testable import ScreenGrid

@Suite struct GridGeometryTests {
    /// A 2560×1440 screen at the global origin.
    let geometry = GridGeometry(screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440))

    /// `G`, `K` selects column 5 (index 4) and row 18 (index 17 — `K` in
    /// the QWERTY block's reading order); the cell frame must be exactly
    /// (4/10·W, 17/30·H, W/10, H/30) — no floating-point drift on grid lines.
    @Test func cellFrameIsExact() {
        #expect(Keys.homeRowIndex(of: 5) == 4) // G
        #expect(Keys.qwertyRowIndex(of: 40) == 17) // K

        let cell = geometry.cellFrame(column: 4, row: 17)
        #expect(cell == CGRect(x: 1024, y: 816, width: 256, height: 48))
    }

    /// Following with `T` targets sub-region (row 0, col 4) of that cell.
    @Test func subRegionForFineGridKey() {
        let position = Keys.fineGridPosition(of: 17) // T
        #expect(position?.row == 0)
        #expect(position?.column == 4)

        // Sub-regions are 1/100 of the screen width × 1/90 of its height.
        let sub = geometry.subRegionFrame(column: 4, row: 17, fineColumn: 4, fineRow: 0)
        #expect(sub.width == 25.6)
        #expect(sub.height == 16)
        #expect(sub.origin == CGPoint(x: 1024 + 4 * 25.6, y: 816))
    }

    @Test func columnsSpanTheScreen() {
        #expect(geometry.columnFrame(0).minX == 0)
        #expect(geometry.columnFrame(9).maxX == 2560)
        #expect(geometry.columnFrame(3).width == 256)
    }

    @Test func cellsSpanTheScreen() {
        #expect(geometry.cellFrame(column: 0, row: 0).minY == 0) // AQ, top-left
        #expect(geometry.cellFrame(column: 9, row: 29).maxY == 1440) // ;/ bottom-right
    }

    @Test func cellCenterIsCellMidpoint() {
        let center = geometry.cellCenter(column: 0, row: 0)
        #expect(center == CGPoint(x: 128, y: 24))
    }

    /// Nudge/free motion is confined to the screen: points past any edge snap
    /// back to that edge so the pointer never roams onto another display, while
    /// interior points pass through untouched.
    @Test func clampConfinesToScreen() {
        #expect(geometry.clamp(CGPoint(x: 1280, y: 720)) == CGPoint(x: 1280, y: 720))
        #expect(geometry.clamp(CGPoint(x: -50, y: 720)) == CGPoint(x: 0, y: 720))
        #expect(geometry.clamp(CGPoint(x: 9999, y: 720)) == CGPoint(x: 2560, y: 720))
        #expect(geometry.clamp(CGPoint(x: 1280, y: -50)) == CGPoint(x: 1280, y: 0))
        #expect(geometry.clamp(CGPoint(x: 1280, y: 9999)) == CGPoint(x: 1280, y: 1440))
        // A corner overshoot clamps on both axes at once.
        #expect(geometry.clamp(CGPoint(x: -50, y: 9999)) == CGPoint(x: 0, y: 1440))
    }

    /// A screen at a non-zero global origin (a second display) clamps to its
    /// own frame, not the primary's — the edges track `screenFrame`.
    @Test func clampRespectsScreenOrigin() {
        let offset = GridGeometry(screenFrame: CGRect(x: 2560, y: 0, width: 1920, height: 1080))
        #expect(offset.clamp(CGPoint(x: 100, y: 500)) == CGPoint(x: 2560, y: 500))
        #expect(offset.clamp(CGPoint(x: 9999, y: 500)) == CGPoint(x: 4480, y: 500))
    }

    @Test func keyTablesAreConsistent() {
        #expect(Keys.homeRow.count == 10)
        #expect(Keys.fineGrid.allSatisfy { $0.count == 10 })
        #expect(Keys.fineGrid.count == 3)
        // The fine grid's middle row is the home row.
        #expect(Keys.fineGrid[1] == Keys.homeRow)
        // The 30 cell-row keys are the fine grid flattened in reading order,
        // all distinct.
        #expect(Keys.qwertyRows.count == 30)
        #expect(Set(Keys.qwertyRows).count == 30)
        #expect(Keys.qwertyRows[0] == 12) // Q first
        #expect(Keys.qwertyRows[29] == 44) // / last
        #expect(Keys.qwertyRowLegends.first == "Q")
        #expect(Keys.qwertyRowLegends.last == "/")
    }
}
