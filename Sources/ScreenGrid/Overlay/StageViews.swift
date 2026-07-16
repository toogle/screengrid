import SwiftUI

// The overlay chrome is deliberately simple: solid dark tiles and washes
// that stay legible over any wallpaper, with no material effects.

/// First keystroke pending — a 10×30 lattice of hairlines; every cell shows
/// its two-letter code (`AQ` top-left … `;/` bottom-right) on a small tile.
struct ColumnsStageView: View {
    var body: some View {
        GeometryReader { proxy in
            let grid = GridGeometry(viewSize: proxy.size)

            HairlineLattice(size: proxy.size)

            ForEach(0..<GridGeometry.columnCount, id: \.self) { column in
                ForEach(0..<GridGeometry.rowCount, id: \.self) { row in
                    LetterTile(text: Keys.homeRowLegends[column] + Keys.qwertyRowLegends[row])
                        .position(grid.cellCenter(column: column, row: row))
                }
            }
        }
    }
}

/// Second keystroke pending — the lattice stays visible while everything
/// outside the chosen column dims behind a darker wash. The column's cells
/// keep their full two-letter codes, rendered exactly as in stage 1.
struct RowsStageView: View {
    let column: Int

    var body: some View {
        GeometryReader { proxy in
            let grid = GridGeometry(viewSize: proxy.size)

            HairlineLattice(size: proxy.size)

            DimmingWash(cutout: grid.columnFrame(column))

            ForEach(0..<GridGeometry.rowCount, id: \.self) { row in
                LetterTile(text: Keys.homeRowLegends[column] + Keys.qwertyRowLegends[row])
                    .position(grid.cellCenter(column: column, row: row))
            }
        }
    }
}

/// Stage 2 — the chosen cell keeps the lattice's hairline border (square
/// corners, same brightness and width) over a dark fill with a soft shadow,
/// subdivided by the 30-key QWERTY block; everything outside dims further.
struct FineGridStageView: View {
    let column: Int
    let row: Int

    var body: some View {
        GeometryReader { proxy in
            let grid = GridGeometry(viewSize: proxy.size)
            let cell = grid.cellFrame(column: column, row: row)
            // Sub-regions are ~1/90 of the screen height; cap the letters so
            // they fit inside on small displays.
            let letterSize = min(11, cell.height / CGFloat(GridGeometry.fineRowCount) * 0.7)

            DimmingWash(cutout: cell, strength: 0.5)

            cellChrome
                .frame(width: cell.width, height: cell.height)
                .position(x: cell.midX, y: cell.midY)

            ForEach(0..<GridGeometry.fineRowCount, id: \.self) { fineRow in
                ForEach(0..<GridGeometry.fineColumnCount, id: \.self) { fineColumn in
                    Text(Keys.fineGridLegends[fineRow][fineColumn])
                        .font(.system(size: letterSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(OverlaySettings.shared.letterOpacity))
                        .position(grid.subRegionCenter(
                            column: column, row: row,
                            fineColumn: fineColumn, fineRow: fineRow
                        ))
                }
            }
        }
    }

    private var cellChrome: some View {
        let settings = OverlaySettings.shared
        return Rectangle()
            .fill(.black.opacity(0.55))
            .overlay(Rectangle().stroke(
                .white.opacity(settings.hairlineOpacity),
                lineWidth: settings.hairlineWidth
            ))
            .shadow(color: .black.opacity(0.4), radius: 16)
    }
}

/// Nudge mode — the fine grid fades out; a small ring with crosshair
/// hairlines tracks the pointer so its exact position stays visible against
/// any background.
struct NudgeStageView: View {
    let pointerLocation: CGPoint?

    private let ringDiameter: CGFloat = 32

    var body: some View {
        if let point = pointerLocation {
            ring.position(point)
        }
    }

    private var ring: some View {
        ZStack {
            Path { path in
                let radius = ringDiameter / 2
                path.move(to: CGPoint(x: radius, y: 0))
                path.addLine(to: CGPoint(x: radius, y: ringDiameter))
                path.move(to: CGPoint(x: 0, y: radius))
                path.addLine(to: CGPoint(x: ringDiameter, y: radius))
            }
            .stroke(.white.opacity(0.9), lineWidth: 0.5)

            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .background(Circle().fill(.black.opacity(0.5)))
    }
}

/// Scroll mode — the grid fades out so the content stays visible; a small
/// chevron badge on a dark disc marks the pointer and the scroll direction.
struct ScrollStageView: View {
    let direction: ScrollDirection
    let pointerLocation: CGPoint?

    private let discDiameter: CGFloat = 32

    var body: some View {
        if let point = pointerLocation {
            badge.position(point)
        }
    }

    private var badge: some View {
        Image(systemName: direction == .up ? "chevron.up" : "chevron.down")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: discDiameter, height: discDiameter)
            .background(Circle().fill(.black.opacity(0.5)))
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
    }
}

// MARK: - Shared pieces

private extension GridGeometry {
    /// Geometry laid over a view's local frame (origin zero). The overlay
    /// panel covers exactly the target screen, so these rects and centers
    /// line up 1:1 with the panel's coordinates — and thus with the click
    /// targets — by construction, instead of a second copy of the fractions.
    init(viewSize: CGSize) {
        self.init(screenFrame: CGRect(origin: .zero, size: viewSize))
    }
}

/// One labeled grid tile: a rounded dark chip behind a rounded-design code.
/// Sized to fit the 1/30-height cell rows. Tiles render identically across
/// all stages. Tile backgrounds can be turned off in Settings.
private struct LetterTile: View {
    let text: String

    private let shape = RoundedRectangle(cornerRadius: 6)

    var body: some View {
        let settings = OverlaySettings.shared
        let label = Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(settings.letterOpacity))
            .padding(.horizontal, 6)
            .frame(minWidth: 24)
            .frame(height: 22)

        if settings.tilesEnabled {
            label
                .background(shape.fill(.black.opacity(0.55)))
                .overlay(shape.stroke(.white.opacity(settings.tileBorderOpacity), lineWidth: 1))
        } else {
            label
        }
    }
}

/// The hairline lattice separating the cell-selection grid, drawn over the
/// view's local frame so it aligns with the cell tiles.
private struct HairlineLattice: View {
    let size: CGSize

    private var cellWidth: CGFloat { size.width / CGFloat(GridGeometry.columnCount) }
    private var cellHeight: CGFloat { size.height / CGFloat(GridGeometry.rowCount) }

    var body: some View {
        let settings = OverlaySettings.shared
        let lattice = self.lattice
        ZStack {
            // A dark under-stroke wider than the hairline reads as a crisp
            // shadow on all-white content — a blur shadow inherits the
            // hairline's low opacity and all but disappears there.
            if settings.lineShadowWidth > 0 {
                lattice.stroke(
                    .black.opacity(settings.lineShadowOpacity),
                    lineWidth: settings.hairlineWidth + settings.lineShadowWidth
                )
            }
            lattice.stroke(.white.opacity(settings.hairlineOpacity), lineWidth: settings.hairlineWidth)
        }
    }

    private var lattice: Path {
        Path { path in
            for column in 1..<GridGeometry.columnCount {
                let x = CGFloat(column) * cellWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 1..<GridGeometry.rowCount {
                let y = CGFloat(row) * cellHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
    }
}

/// Dims everything except `cutout` with an even-odd punch-out.
private struct DimmingWash: View {
    let cutout: CGRect
    var strength: Double = 0.35

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: proxy.size))
                path.addRect(cutout)
            }
            .fill(.black.opacity(strength), style: FillStyle(eoFill: true))
        }
    }
}
