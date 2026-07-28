import AppKit

/// Borderless transparent 32x32 overlay that hosts the cat sprite.
/// Click-through, above full-screen apps and the menu bar, on every Space.
final class CatWindow: NSWindow {
    private let spriteLayer = CALayer()
    private var lastImage: CGImage?

    init() {
        let size = SpriteSheet.frameSize
        super.init(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                   styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary,
                              .ignoresCycle]
        isReleasedWhenClosed = false

        let view = NSView(frame: contentRect(forFrameRect: frame))
        view.wantsLayer = true
        spriteLayer.frame = view.bounds
        spriteLayer.magnificationFilter = .nearest  // keep pixel art crisp on retina
        view.layer?.addSublayer(spriteLayer)
        contentView = view
    }

    func show(_ image: CGImage?) {
        // Frames are cached per sheet, so identity is stable: skip the commit
        // when the sprite hasn't changed (idle/sleeping cat, 10x/sec).
        guard image !== lastImage else { return }
        lastImage = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.contents = image
        CATransaction.commit()
    }

    /// Positions the window so the cat's center sits at `center` (global coords).
    func move(center: CGPoint) {
        let half = SpriteSheet.frameSize / 2
        setFrameOrigin(NSPoint(x: center.x - half, y: center.y - half))
    }
}
