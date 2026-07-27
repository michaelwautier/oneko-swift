import AppKit

/// Slices the classic 256x128 oneko sheet (8x4 grid of 32x32 frames) into
/// per-animation frame lists. Grid coordinates below are (column, row) with
/// row 0 at the top, matching the layout used by oneko.js.
enum SpriteSheet {
    static let frameSize: CGFloat = 32

    private static let grid: [String: [(Int, Int)]] = [
        "idle":         [(3, 3)],
        "alert":        [(7, 3)],
        "tired":        [(3, 2)],
        "sleeping":     [(2, 0), (2, 1)],
        "scratchSelf":  [(5, 0), (6, 0), (7, 0)],
        "scratchWallN": [(0, 0), (0, 1)],
        "scratchWallS": [(7, 1), (6, 2)],
        "scratchWallE": [(2, 2), (2, 3)],
        "scratchWallW": [(4, 0), (4, 1)],
        "N":  [(1, 2), (1, 3)],
        "NE": [(0, 2), (0, 3)],
        "E":  [(3, 0), (3, 1)],
        "SE": [(5, 1), (5, 2)],
        "S":  [(6, 3), (7, 2)],
        "SW": [(5, 3), (6, 1)],
        "W":  [(4, 2), (4, 3)],
        "NW": [(1, 0), (1, 1)],
    ]

    static let frames: [String: [CGImage]] = {
        guard let url = Bundle.main.url(forResource: "oneko", withExtension: "png"),
              let image = NSImage(contentsOf: url),
              let sheet = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            fatalError("oneko.png missing from bundle resources")
        }
        let cell = CGFloat(sheet.width) / 8  // supports @2x sheets too
        var result: [String: [CGImage]] = [:]
        for (name, cells) in grid {
            result[name] = cells.compactMap { col, row in
                sheet.cropping(to: CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell,
                                          width: cell, height: cell))
            }
        }
        return result
    }()

    static func frame(_ name: String, _ index: Int) -> CGImage? {
        guard let list = frames[name], !list.isEmpty else { return nil }
        return list[((index % list.count) + list.count) % list.count]
    }
}
