import AppKit

// Generates the Icon Composer bundle Support/AppIcon.icon, the Tahoe-native
// (macOS 26) app-icon format. The bundle holds a manifest (icon.json) plus
// flat layer art in Assets/; the system draws the squircle, shadow, and
// Liquid Glass lighting, so the artwork is a plain transparent glyph — no
// baked plate, gradient, or shadow.
//
//   swift Support/generate-appicon.swift
//
// The build workflow compiles the bundle into the app with actool (full
// Xcode). The artwork riffs on the menu bar's square.grid.3x3 symbol: a 3x3
// grid of translucent cells with the center cell lit to suggest a grid
// region being picked. The blue background is the manifest fill.

/// Renders the grid glyph as a 1024×1024 transparent PNG. Eight cells are
/// translucent white so the manifest fill shows through; the center cell is
/// opaque — the picked region.
func renderGrid() -> Data {
    let side = 1024
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gctx
    let cg = gctx.cgContext

    // Cells 180pt with 46pt gutters, centered on the 1024 canvas — the grid
    // sits well inside the squircle's safe area.
    let cell: CGFloat = 180
    let gap: CGFloat = 46
    let origin: CGFloat = 512 - (cell * 3 + gap * 2) / 2

    func cellPath(col: Int, row: Int) -> CGPath {
        CGPath(
            roundedRect: CGRect(
                x: origin + CGFloat(col) * (cell + gap),
                y: origin + CGFloat(row) * (cell + gap),
                width: cell, height: cell
            ),
            cornerWidth: 40, cornerHeight: 40, transform: nil
        )
    }

    cg.setFillColor(CGColor(gray: 1, alpha: 0.42))
    for col in 0...2 {
        for row in 0...2 where (col, row) != (1, 1) {
            cg.addPath(cellPath(col: col, row: row))
        }
    }
    cg.fillPath()

    cg.setFillColor(CGColor(gray: 1, alpha: 1))
    cg.addPath(cellPath(col: 1, row: 1))
    cg.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// The manifest. A solid blue fill (the system layers its own top-down glass
// lighting over it); one group carrying the grid, with a neutral drop shadow
// and specular highlight for depth.
let manifest = """
{
  "fill" : {
    "solid" : "srgb:0.20000,0.34000,0.86000,1.00000"
  },
  "groups" : [
    {
      "name" : "Grid",
      "shadow" : {
        "kind" : "neutral",
        "opacity" : 0.5
      },
      "specular" : true,
      "layers" : [
        {
          "image-name" : "Grid.png",
          "name" : "Grid"
        }
      ]
    }
  ],
  "supported-platforms" : {
    "squares" : "shared"
  }
}

"""

let bundle = URL(fileURLWithPath: "Support/AppIcon.icon")
let assets = bundle.appendingPathComponent("Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try renderGrid().write(to: assets.appendingPathComponent("Grid.png"))
try manifest.write(to: bundle.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
print("Wrote \(bundle.path)")
