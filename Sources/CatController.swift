import AppKit

/// Drives the cat: a direct port of the oneko.js state machine (run in 8
/// directions, alert, idle, random wash/wall-scratch, tired, sleep), adapted
/// to AppKit's y-up coordinate space. Runs on a ~100 ms timer, matching the
/// original's frame cadence.
final class CatController {
    private let window = CatWindow()
    private var timer: Timer?

    var strategy: TargetStrategy = FullChaseStrategy() {
        didSet { wake() }
    }
    /// Pixels moved per tick; oneko.js default is 10 per 100 ms.
    var speed: CGFloat = 10

    private var pos: CGPoint
    private var frameCount = 0
    private var idleTime = 0
    private var idleAnimation: String?
    private var idleAnimationFrame = 0

    init() {
        let screen = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 800, height: 600)
        pos = CGPoint(x: screen.midX, y: screen.midY)
    }

    func start() {
        guard timer == nil else { return }
        window.move(center: pos)
        window.orderFrontRegardless()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.02
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        window.orderOut(nil)
    }

    var isRunning: Bool { timer != nil }

    /// Interrupt sleep/idle animations, e.g. when settings change.
    private func wake() {
        resetIdleAnimation()
        idleTime = 0
    }

    private func resetIdleAnimation() {
        idleAnimation = nil
        idleAnimationFrame = 0
    }

    private func setSprite(_ name: String, _ index: Int) {
        window.show(SpriteSheet.frame(name, index))
    }

    private func tick() {
        let target = strategy.target(forMouse: NSEvent.mouseLocation)
        frameCount += 1

        let dx = target.x - pos.x
        let dy = target.y - pos.y
        let distance = (dx * dx + dy * dy).squareRoot()

        if distance < max(speed, 48) {
            idle()
            return
        }
        idleAnimation = nil
        idleAnimationFrame = 0

        if idleTime > 1 {
            setSprite("alert", 0)
            // Delay leaving alert pose proportional to how long the cat slept.
            idleTime = min(idleTime, 7) - 1
            return
        }

        // AppKit is y-up, so dy > 0 means the target is above the cat → run N.
        var direction = ""
        if dy / distance > 0.5 { direction += "N" }
        if dy / distance < -0.5 { direction += "S" }
        if dx / distance < -0.5 { direction += "W" }
        if dx / distance > 0.5 { direction += "E" }
        setSprite(direction, frameCount)

        pos.x += dx / distance * speed
        pos.y += dy / distance * speed

        // Keep the cat on the screen it's headed toward.
        let bounds = screenContaining(target).frame
        let half = SpriteSheet.frameSize / 2
        pos.x = min(max(pos.x, bounds.minX + half), bounds.maxX - half)
        pos.y = min(max(pos.y, bounds.minY + half), bounds.maxY - half)

        window.move(center: pos)
    }

    private func idle() {
        idleTime += 1

        // Rarely start a one-off idle animation (sleep, wash, or scratch a
        // nearby screen edge) — same odds as oneko.js.
        if idleTime > 10, Int.random(in: 0..<200) == 0, idleAnimation == nil {
            var options = ["sleeping", "scratchSelf"]
            let bounds = screenContaining(pos).frame
            if pos.x < bounds.minX + 32 { options.append("scratchWallW") }
            if pos.x > bounds.maxX - 32 { options.append("scratchWallE") }
            if pos.y > bounds.maxY - 32 { options.append("scratchWallN") }
            if pos.y < bounds.minY + 32 { options.append("scratchWallS") }
            idleAnimation = options.randomElement()
        }

        switch idleAnimation {
        case "sleeping":
            if idleAnimationFrame < 8 {
                setSprite("tired", 0)
            } else {
                setSprite("sleeping", idleAnimationFrame / 4)
            }
            if idleAnimationFrame > 192 { resetIdleAnimation() }
        case "scratchSelf", "scratchWallN", "scratchWallS", "scratchWallE", "scratchWallW":
            setSprite(idleAnimation!, idleAnimationFrame)
            if idleAnimationFrame > 9 { resetIdleAnimation() }
        default:
            setSprite("idle", 0)
            return
        }
        idleAnimationFrame += 1
    }
}
