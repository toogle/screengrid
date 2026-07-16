import CoreGraphics

/// Physical ANSI key codes (`kVK_ANSI_*`). All stage handling is by physical
/// key position, so the grid works on any keyboard layout; the legends are
/// the US-QWERTY glyphs.
enum Keys {
    // MARK: Special keys

    static let leftCommand: CGKeyCode = 55
    static let rightCommand: CGKeyCode = 54
    static let space: CGKeyCode = 49
    static let returnKey: CGKeyCode = 36
    static let escape: CGKeyCode = 53
    static let backspace: CGKeyCode = 51 // "delete" on Mac keyboards
    static let arrowLeft: CGKeyCode = 123
    static let arrowRight: CGKeyCode = 124
    static let arrowDown: CGKeyCode = 125
    static let arrowUp: CGKeyCode = 126

    static let arrows: Set<CGKeyCode> = [arrowLeft, arrowRight, arrowDown, arrowUp]

    /// Device-specific `flagsChanged` flag bits distinguishing left from
    /// right Command (NX_DEVICELCMDKEYMASK / NX_DEVICERCMDKEYMASK). Only the
    /// left key activates the overlay.
    static let deviceLeftCommandMask: UInt64 = 0x0000_0008
    static let deviceRightCommandMask: UInt64 = 0x0000_0010

    // MARK: Home row — cell columns (first letter)

    /// `A S D F G H J K L ;` — index is the column.
    static let homeRow: [CGKeyCode] = [0, 1, 2, 3, 5, 4, 38, 40, 37, 41]

    static let homeRowLegends: [String] = ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";"]

    // MARK: QWERTY block — cell rows (second letter) and the fine grid

    /// The full QWERTY letter block, 10 wide × 3 tall, mirrored from the
    /// physical keyboard so the sub-grid is spatially congruent with the
    /// fingers. `fineGrid[row][column]`.
    static let fineGrid: [[CGKeyCode]] = [
        [12, 13, 14, 15, 17, 16, 32, 34, 31, 35], // Q W E R T Y U I O P
        [0, 1, 2, 3, 5, 4, 38, 40, 37, 41],       // A S D F G H J K L ;
        [6, 7, 8, 9, 11, 45, 46, 43, 47, 44],     // Z X C V B N M , . /
    ]

    static let fineGridLegends: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";"],
        ["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"],
    ]

    /// The QWERTY block flattened in reading order (`Q`…`P`, `A`…`;`,
    /// `Z`…`/`) — index is the cell row, 0 (top) to 29 (bottom). Reading
    /// order keeps the keyboard's three letter rows congruent with the
    /// screen's thirds.
    static let qwertyRows: [CGKeyCode] = fineGrid.flatMap(\.self)

    static let qwertyRowLegends: [String] = fineGridLegends.flatMap(\.self)

    // MARK: Scroll mode

    /// `,` (scroll down) and `.` (scroll up), meaningful only at stage 1 —
    /// once a column is chosen the same physical keys keep their grid roles.
    static let comma: CGKeyCode = 43
    static let period: CGKeyCode = 47

    // MARK: Lookup

    /// Home row index (0–9) for a key code, or nil if it is not a home row key.
    static func homeRowIndex(of code: CGKeyCode) -> Int? {
        homeRow.firstIndex(of: code)
    }

    /// Cell row index (0–29) for a key code, or nil if it is outside the
    /// QWERTY block.
    static func qwertyRowIndex(of code: CGKeyCode) -> Int? {
        qwertyRows.firstIndex(of: code)
    }

    /// Unit displacement an arrow key applies to the pointer in nudge/free
    /// mode, in Quartz coordinates (y grows downward), or nil for any
    /// non-arrow key. Scaled by the nudge step (a fine 1 pt with Shift held).
    static func arrowVector(of code: CGKeyCode) -> CGVector? {
        switch code {
        case arrowLeft: CGVector(dx: -1, dy: 0)
        case arrowRight: CGVector(dx: 1, dy: 0)
        case arrowUp: CGVector(dx: 0, dy: -1)
        case arrowDown: CGVector(dx: 0, dy: 1)
        default: nil
        }
    }

    /// Unit-length direction of every key currently held: a vertical and a
    /// horizontal arrow held together steer diagonally, opposite arrows
    /// cancel (zero vector), and non-arrow keys contribute nothing.
    static func combinedArrowVector(of codes: Set<CGKeyCode>) -> CGVector {
        let sum = codes.reduce(into: CGVector.zero) { sum, code in
            guard let vector = arrowVector(of: code) else { return }
            sum.dx += vector.dx
            sum.dy += vector.dy
        }
        // Normalized to unit length: a vertical + horizontal pair steers
        // diagonally at the same pace as a single arrow, not √2× faster.
        let length = (sum.dx * sum.dx + sum.dy * sum.dy).squareRoot()
        guard length > 0 else { return .zero }
        return CGVector(dx: sum.dx / length, dy: sum.dy / length)
    }

    /// Fine grid position for a key code, or nil if it is outside the block.
    static func fineGridPosition(of code: CGKeyCode) -> (row: Int, column: Int)? {
        for (row, keys) in fineGrid.enumerated() {
            if let column = keys.firstIndex(of: code) {
                return (row, column)
            }
        }
        return nil
    }
}
