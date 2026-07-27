import AppKit

/// The bundled sprite sheets. All variants share the classic oneko.js layout,
/// so they are interchangeable at runtime.
struct SpriteVariant: Hashable {
    /// Persisted in UserDefaults; also the resource file name (except `cat`,
    /// whose sheet keeps its historical name `oneko.png`).
    let rawValue: String
    let title: String

    private init(_ rawValue: String, _ title: String) {
        self.rawValue = rawValue
        self.title = title
    }

    init?(rawValue: String) {
        guard let match = Self.allCases.first(where: { $0.rawValue == rawValue })
        else { return nil }
        self = match
    }

    var resourceName: String { rawValue == "cat" ? "oneko" : rawValue }

    static let cat = SpriteVariant("cat", "Cat")

    /// Menu grouping: the two sheets bundled since the first release, the
    /// remaining characters of the original X11 oneko, and community art.
    static let groups: [(name: String, variants: [SpriteVariant])] = [
        ("Classic", [
            cat,
            SpriteVariant("dog", "Dog"),
        ]),
        ("X11 Originals", [
            SpriteVariant("tora-x11", "Tora"),
            SpriteVariant("sakura", "Sakura"),
            SpriteVariant("tomoyo", "Tomoyo"),
            SpriteVariant("bsd", "BSD Daemon"),
        ]),
        ("Community", [
            SpriteVariant("ace", "Ace"),
            SpriteVariant("black", "Black"),
            SpriteVariant("bunny", "Bunny"),
            SpriteVariant("calico", "Calico"),
            SpriteVariant("catppuccin", "Catppuccin"),
            SpriteVariant("eevee", "Eevee"),
            SpriteVariant("esmeralda", "Esmeralda"),
            SpriteVariant("fox", "Fox"),
            SpriteVariant("ghost", "Ghost"),
            SpriteVariant("gray", "Gray"),
            SpriteVariant("jess", "Jess"),
            SpriteVariant("kina", "Kina"),
            SpriteVariant("lucy", "Lucy"),
            SpriteVariant("maia", "Maia"),
            SpriteVariant("maria", "Maria"),
            SpriteVariant("mike", "Mike"),
            SpriteVariant("silver", "Silver"),
            SpriteVariant("silversky", "Silver Sky"),
            SpriteVariant("snuupy", "Snuupy"),
            SpriteVariant("spirit", "Spirit"),
            SpriteVariant("tora", "Tora (Color)"),
            SpriteVariant("valentine", "Valentine"),
            SpriteVariant("vaporwave", "Vaporwave"),
        ]),
    ]

    static let allCases: [SpriteVariant] = groups.flatMap { $0.variants }
}

/// Slices a 256x128 oneko-style sheet (8x4 grid of 32x32 frames) into
/// per-animation frame lists. Grid coordinates below are (column, row) with
/// row 0 at the top, matching the layout used by oneko.js.
final class SpriteSheet {
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

    private static var cache: [SpriteVariant: SpriteSheet] = [:]

    static func sheet(for variant: SpriteVariant) -> SpriteSheet {
        if let cached = cache[variant] { return cached }
        guard let sheet = SpriteSheet(resourceName: variant.resourceName) else {
            fatalError("\(variant.resourceName).png missing from bundle resources")
        }
        cache[variant] = sheet
        return sheet
    }

    private let frames: [String: [CGImage]]

    private init?(resourceName: String) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url),
              let sheet = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let cell = CGFloat(sheet.width) / 8  // supports @2x sheets too
        var result: [String: [CGImage]] = [:]
        for (name, cells) in Self.grid {
            result[name] = cells.compactMap { col, row in
                sheet.cropping(to: CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell,
                                          width: cell, height: cell))
            }
        }
        frames = result
    }

    func frame(_ name: String, _ index: Int) -> CGImage? {
        guard let list = frames[name], !list.isEmpty else { return nil }
        return list[((index % list.count) + list.count) % list.count]
    }
}
