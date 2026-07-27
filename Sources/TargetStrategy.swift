import AppKit

/// Computes where the cat should run to for a given global mouse location.
/// This is the single swappable piece that distinguishes full 2D chasing from
/// horizontal-only mode; the animation/direction code never branches on mode.
protocol TargetStrategy {
    func target(forMouse mouse: CGPoint) -> CGPoint
}

func screenContaining(_ point: CGPoint) -> NSScreen {
    NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
        ?? NSScreen.main
        ?? NSScreen.screens[0]
}

/// Classic behavior: chase the cursor anywhere on any screen.
struct FullChaseStrategy: TargetStrategy {
    func target(forMouse mouse: CGPoint) -> CGPoint { mouse }
}

enum DockEdge: String {
    case top, bottom
}

/// Horizontal-only mode: the cat ignores the cursor's y entirely and stays
/// pinned to a row along the top or bottom edge. The row belongs to whichever
/// screen currently contains the cursor, so the cat follows the cursor across
/// monitors (running to the new screen's edge row when the cursor switches).
struct HorizontalPinnedStrategy: TargetStrategy {
    let edge: DockEdge

    func target(forMouse mouse: CGPoint) -> CGPoint {
        let frame = screenContaining(mouse).frame
        let half = SpriteSheet.frameSize / 2
        let y = edge == .top ? frame.maxY - half : frame.minY + half
        return CGPoint(x: mouse.x, y: y)
    }
}
