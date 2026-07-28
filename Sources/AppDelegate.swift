import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let cat = CatController()
    private var statusItem: NSStatusItem!

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let hidden = "catHidden"
        static let speed = "catSpeed"
        static let horizontal = "horizontalMode"
        static let edge = "dockEdge"
        static let variant = "spriteVariant"
        static let display = "lockedDisplay"
        static let displayName = "lockedDisplayName"
        static let displayUUID = "lockedDisplayUUID"
    }

    // Menu items whose state we refresh.
    private var showHideItem: NSMenuItem!
    private var horizontalItem: NSMenuItem!
    private var topItem: NSMenuItem!
    private var bottomItem: NSMenuItem!
    private var speedItems: [NSMenuItem] = []
    private var variantItems: [NSMenuItem] = []
    private var displayMenu: NSMenu!
    private var displayItems: [NSMenuItem] = []
    private var loginItem: NSMenuItem!

    private static let speeds: [(String, CGFloat)] = [
        ("Slow", 5), ("Normal", 10), ("Fast", 20),
    ]

    /// URLs can arrive before applicationDidFinishLaunching when the app is
    /// launched by an open request; the menu isn't built yet, so hold them.
    private var pendingURLs: [URL] = []
    private var finishedLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        reconcileLockedDisplay()
        setUpStatusItem()
        applySettings()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if !defaults.bool(forKey: Keys.hidden) {
            cat.start()
        }
        refreshMenuState()
        finishedLaunching = true
        pendingURLs.forEach(handle)
        pendingURLs.removeAll()
    }

    // MARK: - URL scheme (oneko://)

    func application(_ application: NSApplication, open urls: [URL]) {
        guard finishedLaunching else {
            pendingURLs.append(contentsOf: urls)
            return
        }
        urls.forEach(handle)
    }

    /// oneko://show | hide | toggle | quit
    /// oneko://skin/<variant>       (SpriteVariant rawValue, e.g. sakura)
    /// oneko://speed/<slow|normal|fast>
    private func handle(_ url: URL) {
        let argument = url.pathComponents.dropFirst().first
        switch url.host {
        case "show": setShown(true)
        case "hide": setShown(false)
        case "toggle": setShown(!cat.isRunning)
        case "quit": NSApp.terminate(nil)
        case "skin":
            guard let variant = argument.flatMap(SpriteVariant.init(rawValue:)) else {
                return NSLog("Unknown skin in URL: \(url)")
            }
            defaults.set(variant.rawValue, forKey: Keys.variant)
            applySettings()
            refreshMenuState()
        case "speed":
            guard let value = Self.speeds.first(where: {
                $0.0.lowercased() == argument?.lowercased()
            })?.1 else {
                return NSLog("Unknown speed in URL: \(url)")
            }
            defaults.set(Double(value), forKey: Keys.speed)
            applySettings()
            refreshMenuState()
        default:
            NSLog("Unknown URL command: \(url)")
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Fallbacks if the bundled icon is missing: cat.fill needs macOS 14,
        // pawprint.fill covers 13.
        if let icon = Self.makeStatusIcon() {
            statusItem.button?.image = icon
        } else if let icon = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Oneko")
            ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Oneko") {
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "🐱"
        }

        let menu = NSMenu()

        let speedMenu = NSMenu()
        for (name, value) in Self.speeds {
            let item = speedMenu.addItem(withTitle: name,
                                         action: #selector(setSpeed(_:)), keyEquivalent: "")
            item.representedObject = value
            speedItems.append(item)
        }
        let speedItem = menu.addItem(withTitle: "Speed", action: nil, keyEquivalent: "")
        speedItem.submenu = speedMenu

        let variantMenu = NSMenu()
        for (groupName, variants) in SpriteVariant.groups {
            let groupMenu = NSMenu()
            for variant in variants {
                let item = groupMenu.addItem(withTitle: variant.title,
                                             action: #selector(setVariant(_:)), keyEquivalent: "")
                item.representedObject = variant.rawValue
                item.image = SpriteSheet.menuIcon(for: variant)
                variantItems.append(item)
            }
            let groupItem = variantMenu.addItem(withTitle: groupName, action: nil, keyEquivalent: "")
            groupItem.submenu = groupMenu
        }
        let variantItem = menu.addItem(withTitle: "Sprite", action: nil, keyEquivalent: "")
        variantItem.submenu = variantMenu

        displayMenu = NSMenu()
        // Manual isEnabled control for the "(disconnected)" indicator row.
        displayMenu.autoenablesItems = false
        rebuildDisplayMenu()
        let displayItem = menu.addItem(withTitle: "Display", action: nil, keyEquivalent: "")
        displayItem.submenu = displayMenu

        horizontalItem = menu.addItem(withTitle: "Horizontal-Only Mode",
                                      action: #selector(toggleHorizontal), keyEquivalent: "")
        let edgeMenu = NSMenu()
        // Auto-enablement would keep these clickable even when horizontal mode
        // is off; refreshMenuState manages isEnabled itself.
        edgeMenu.autoenablesItems = false
        topItem = edgeMenu.addItem(withTitle: "Dock to Top",
                                   action: #selector(setEdge(_:)), keyEquivalent: "")
        topItem.representedObject = DockEdge.top.rawValue
        bottomItem = edgeMenu.addItem(withTitle: "Dock to Bottom",
                                      action: #selector(setEdge(_:)), keyEquivalent: "")
        bottomItem.representedObject = DockEdge.bottom.rawValue
        let edgeItem = menu.addItem(withTitle: "Dock Edge", action: nil, keyEquivalent: "")
        edgeItem.submenu = edgeMenu

        menu.addItem(.separator())
        loginItem = menu.addItem(withTitle: "Launch at Login",
                                 action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.addItem(.separator())
        showHideItem = menu.addItem(withTitle: "Hide Cat",
                            action: #selector(toggleShown), keyEquivalent: "")
        menu.addItem(withTitle: "Quit Oneko", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items { item.target = self }
        for item in speedItems + variantItems + [topItem!, bottomItem!] { item.target = self }
        statusItem.menu = menu
    }

    /// One item per connected screen, plus "All Displays". Rebuilt whenever
    /// displays are added, removed, or rearranged.
    private func rebuildDisplayMenu() {
        displayMenu.removeAllItems()
        displayItems.removeAll()
        let all = displayMenu.addItem(withTitle: "All Displays",
                                      action: #selector(setDisplay(_:)), keyEquivalent: "")
        displayItems.append(all)
        displayMenu.addItem(.separator())
        var seenNames: [String: Int] = [:]
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            // Identical monitors report the same localizedName; number them.
            var name = screen.localizedName
            let n = seenNames[name, default: 0] + 1
            seenNames[name] = n
            if n > 1 { name += " (\(n))" }
            let item = displayMenu.addItem(withTitle: name,
                                           action: #selector(setDisplay(_:)), keyEquivalent: "")
            item.representedObject = Int(id)
            displayItems.append(item)
        }
        // Keep the lock visible while its display is unplugged, so the
        // unchecked list doesn't read as "no lock active".
        if let id = lockedDisplayID, !NSScreen.screens.contains(where: { $0.displayID == id }) {
            let name = defaults.string(forKey: Keys.displayName) ?? "Locked Display"
            let item = displayMenu.addItem(withTitle: "\(name) (disconnected)",
                                           action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.representedObject = Int(id)
            displayItems.append(item)
        }
        for item in displayItems { item.target = self }
    }

    @objc private func screensChanged() {
        // Re-apply only when the ID moved: the active DisplayLockedStrategy
        // captured its ID at applySettings time, but replacing the strategy
        // wakes the cat, so don't do it for every resolution change.
        if reconcileLockedDisplay() { applySettings() }
        rebuildDisplayMenu()
        refreshMenuState()
    }

    /// oneko-icon.png is 15x15 pixel art. A drawing handler renders it per
    /// backing scale with interpolation off, so it stays crisp on any display.
    private static func makeStatusIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "oneko-icon", withExtension: "png"),
              let base = NSImage(contentsOf: url),
              let cg = base.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        // The asset is 1x art: its pixel size is its point size.
        let size = NSSize(width: cg.width, height: cg.height)
        let icon = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: rect)
            return true
        }
        icon.accessibilityDescription = "Oneko"
        return icon
    }

    // MARK: - Settings

    private var dockEdge: DockEdge {
        DockEdge(rawValue: defaults.string(forKey: Keys.edge) ?? "") ?? .bottom
    }

    private var spriteVariant: SpriteVariant {
        SpriteVariant(rawValue: defaults.string(forKey: Keys.variant) ?? "") ?? .cat
    }

    private var speed: Double {
        defaults.object(forKey: Keys.speed) as? Double ?? 10
    }

    /// UInt32(exactly:) guards against out-of-range values from a corrupted
    /// plist or a manual `defaults write`; invalid means unlocked.
    private var lockedDisplayID: CGDirectDisplayID? {
        (defaults.object(forKey: Keys.display) as? Int).flatMap { UInt32(exactly: $0) }
    }

    private static func uuid(forDisplay id: CGDirectDisplayID) -> String? {
        guard let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, cf) as String
    }

    /// Display IDs aren't stable across reboots or some dock reconnects, and
    /// can even swap between two still-connected monitors. Re-match the lock
    /// by display UUID and adopt that screen's current ID. Returns true when
    /// the stored ID changed.
    @discardableResult
    private func reconcileLockedDisplay() -> Bool {
        guard let id = lockedDisplayID,
              let uuid = defaults.string(forKey: Keys.displayUUID),
              let newID = NSScreen.screens.first(where: {
                  $0.displayID.flatMap(Self.uuid(forDisplay:)) == uuid
              })?.displayID,
              newID != id
        else { return false }
        defaults.set(Int(newID), forKey: Keys.display)
        return true
    }

    private func applySettings() {
        cat.speed = CGFloat(speed)
        cat.variant = spriteVariant
        var strategy: TargetStrategy = defaults.bool(forKey: Keys.horizontal)
            ? HorizontalPinnedStrategy(edge: dockEdge)
            : FullChaseStrategy()
        if let id = lockedDisplayID {
            strategy = DisplayLockedStrategy(base: strategy, displayID: id)
        }
        cat.strategy = strategy
    }

    private func refreshMenuState() {
        showHideItem.title = cat.isRunning ? "Hide Cat" : "Show Cat"
        let horizontal = defaults.bool(forKey: Keys.horizontal)
        horizontalItem.state = horizontal ? .on : .off
        topItem.state = dockEdge == .top ? .on : .off
        bottomItem.state = dockEdge == .bottom ? .on : .off
        topItem.isEnabled = horizontal
        bottomItem.isEnabled = horizontal
        for item in speedItems {
            item.state = (item.representedObject as? CGFloat) == CGFloat(speed) ? .on : .off
        }
        for item in variantItems {
            item.state = (item.representedObject as? String) == spriteVariant.rawValue ? .on : .off
        }
        for item in displayItems {
            item.state = (item.representedObject as? Int) == lockedDisplayID.map(Int.init)
                ? .on : .off
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func toggleShown() {
        setShown(!cat.isRunning)
    }

    private func setShown(_ shown: Bool) {
        if shown != cat.isRunning {
            shown ? cat.start() : cat.stop()
        }
        defaults.set(!shown, forKey: Keys.hidden)
        refreshMenuState()
    }

    @objc private func setSpeed(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? CGFloat else { return }
        defaults.set(Double(value), forKey: Keys.speed)
        applySettings()
        refreshMenuState()
    }

    @objc private func setVariant(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        defaults.set(raw, forKey: Keys.variant)
        applySettings()
        refreshMenuState()
    }

    @objc private func setDisplay(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? Int, let did = UInt32(exactly: id) {
            defaults.set(id, forKey: Keys.display)
            // UUID is the durable identity (reconcile key); raw localizedName
            // (not the menu title with its "(2)" suffix) only labels the
            // disconnected-indicator row.
            if let uuid = Self.uuid(forDisplay: did) {
                defaults.set(uuid, forKey: Keys.displayUUID)
            } else {
                defaults.removeObject(forKey: Keys.displayUUID)
            }
            if let name = NSScreen.screens
                .first(where: { $0.displayID == did })?.localizedName {
                defaults.set(name, forKey: Keys.displayName)
            } else {
                defaults.removeObject(forKey: Keys.displayName)
            }
        } else {
            defaults.removeObject(forKey: Keys.display)
            defaults.removeObject(forKey: Keys.displayName)
            defaults.removeObject(forKey: Keys.displayUUID)
        }
        applySettings()
        refreshMenuState()
    }

    @objc private func toggleHorizontal() {
        defaults.set(!defaults.bool(forKey: Keys.horizontal), forKey: Keys.horizontal)
        applySettings()
        refreshMenuState()
    }

    @objc private func setEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        defaults.set(raw, forKey: Keys.edge)
        applySettings()
        refreshMenuState()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
        refreshMenuState()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
