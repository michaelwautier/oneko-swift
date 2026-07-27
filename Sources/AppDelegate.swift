import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let cat = CatController()
    private var statusItem: NSStatusItem!
    private var activity: NSObjectProtocol?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let hidden = "catHidden"
        static let speed = "catSpeed"
        static let horizontal = "horizontalMode"
        static let edge = "dockEdge"
        static let variant = "spriteVariant"
    }

    // Menu items whose state we refresh.
    private var showHideItem: NSMenuItem!
    private var horizontalItem: NSMenuItem!
    private var topItem: NSMenuItem!
    private var bottomItem: NSMenuItem!
    private var speedItems: [NSMenuItem] = []
    private var variantItems: [NSMenuItem] = []
    private var loginItem: NSMenuItem!

    private static let speeds: [(String, CGFloat)] = [
        ("Slow", 5), ("Normal", 10), ("Fast", 20),
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Keep the animation timer steady even though we're a background app.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Cat animation")

        setUpStatusItem()
        applySettings()
        if !defaults.bool(forKey: Keys.hidden) {
            cat.start()
        }
        refreshMenuState()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let icon = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Oneko") {
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "🐱"
        }

        let menu = NSMenu()

        showHideItem = menu.addItem(withTitle: "Hide Cat",
                                    action: #selector(toggleShown), keyEquivalent: "")
        menu.addItem(.separator())

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
                if let idle = SpriteSheet.sheet(for: variant).frame("idle", 0) {
                    // 32px frame at 16pt: 1:1 pixels on Retina, downsampled on 1x.
                    item.image = NSImage(cgImage: idle, size: NSSize(width: 16, height: 16))
                }
                variantItems.append(item)
            }
            let groupItem = variantMenu.addItem(withTitle: groupName, action: nil, keyEquivalent: "")
            groupItem.submenu = groupMenu
        }
        let variantItem = menu.addItem(withTitle: "Sprite", action: nil, keyEquivalent: "")
        variantItem.submenu = variantMenu

        horizontalItem = menu.addItem(withTitle: "Horizontal-Only Mode",
                                      action: #selector(toggleHorizontal), keyEquivalent: "")
        let edgeMenu = NSMenu()
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
        menu.addItem(withTitle: "Quit Oneko", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items { item.target = self }
        for item in speedItems + variantItems + [topItem!, bottomItem!] { item.target = self }
        statusItem.menu = menu
    }

    // MARK: - Settings

    private var dockEdge: DockEdge {
        DockEdge(rawValue: defaults.string(forKey: Keys.edge) ?? "") ?? .bottom
    }

    private var spriteVariant: SpriteVariant {
        SpriteVariant(rawValue: defaults.string(forKey: Keys.variant) ?? "") ?? .cat
    }

    private func applySettings() {
        let speed = defaults.object(forKey: Keys.speed) as? Double ?? 10
        cat.speed = CGFloat(speed)
        cat.variant = spriteVariant
        cat.strategy = defaults.bool(forKey: Keys.horizontal)
            ? HorizontalPinnedStrategy(edge: dockEdge)
            : FullChaseStrategy()
    }

    private func refreshMenuState() {
        showHideItem.title = cat.isRunning ? "Hide Cat" : "Show Cat"
        let horizontal = defaults.bool(forKey: Keys.horizontal)
        horizontalItem.state = horizontal ? .on : .off
        topItem.state = dockEdge == .top ? .on : .off
        bottomItem.state = dockEdge == .bottom ? .on : .off
        topItem.isEnabled = horizontal
        bottomItem.isEnabled = horizontal
        let speed = defaults.object(forKey: Keys.speed) as? Double ?? 10
        for item in speedItems {
            item.state = (item.representedObject as? CGFloat) == CGFloat(speed) ? .on : .off
        }
        for item in variantItems {
            item.state = (item.representedObject as? String) == spriteVariant.rawValue ? .on : .off
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func toggleShown() {
        if cat.isRunning { cat.stop() } else { cat.start() }
        defaults.set(!cat.isRunning, forKey: Keys.hidden)
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
