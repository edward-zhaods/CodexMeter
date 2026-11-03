import AppKit

@main
enum AgentPalsMain {
    static func main() {
        MainActor.assumeIsolated {
            let application = NSApplication.shared
            let delegate = AppDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            application.run()
            // delegate is unowned by NSApplication. A use after run() keeps it
            // alive for the whole run loop; otherwise the status item vanishes.
            withExtendedLifetime(delegate) {}
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = ActivityMonitor()
    private var statusItem: NSStatusItem!
    private var snapshot = ActivitySnapshot()
    private var tick = 8
    private var frameTimer: Timer?
    private var displayedKey = ""
    private var statusRows: [PetKind: NSMenuItem] = [:]

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // The status bar drops items created before launch finishes.
        // Preferred position is distance from the right edge; a small value
        // stays with the system icons instead of the notch overflow.
        let positionKey = "NSStatusItem Preferred Position AgentPals"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(0, forKey: positionKey)
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "AgentPals"
        item.isVisible = true
        statusItem = item
        configureStatusItem()

        let timer = Timer(
            timeInterval: 1.0 / 8.0,
            target: self,
            selector: #selector(advanceFrameTick(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(motionOptionsChanged(_:)),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )

        refreshActivity()
        updateImage(force: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        frameTimer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuTitles()
    }

    private func configureStatusItem() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        for kind in PetKind.allCases {
            let item = statusRow(title: kind.title)
            statusRows[kind] = item
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        updateMenuTitles()
    }

    private func statusRow(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: "\(title)：闲着", action: nil, keyEquivalent: "")
        item.isEnabled = true
        return item
    }

    @objc private func advanceFrameTick(_ timer: Timer) {
        advanceFrame()
    }

    private func advanceFrame() {
        tick &+= 1
        if tick % 8 == 0 {
            refreshActivity()
        }
        updateImage(force: false)
    }

    private func refreshActivity() {
        let snapshot = monitor.poll()
        guard snapshot != self.snapshot else { return }
        self.snapshot = snapshot
        updateMenuTitles()
    }

    private func updateMenuTitles() {
        for kind in PetKind.allCases {
            statusRows[kind]?.title = rowTitle(kind.title, working: isWorking(kind))
        }
    }

    private func isWorking(_ kind: PetKind) -> Bool {
        switch kind {
        case .claude:
            return snapshot.claude
        case .codex:
            return snapshot.codex
        case .cursor:
            return snapshot.cursor
        case .agy:
            return snapshot.agy
        }
    }

    private func rowTitle(_ name: String, working: Bool) -> String {
        "\(name)：\(working ? "工作中" : "闲着")"
    }

    private var tooltip: String {
        PetKind.allCases.map { "\($0.title) \(stateWord(isWorking($0)))" }.joined(separator: " · ")
    }

    private func stateWord(_ working: Bool) -> String {
        working ? "工作中" : "闲着"
    }

    private func updateImage(force: Bool) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let working = PetKind.allCases.reduce(into: [PetKind: Bool]()) { flags, kind in
            flags[kind] = isWorking(kind)
        }
        let key = PixelSprites.cacheKey(working: working, tick: tick, reduceMotion: reduceMotion)
        guard force || key != displayedKey else { return }
        displayedKey = key

        let image = PixelSprites.image(working: working, tick: tick, reduceMotion: reduceMotion)
        image.isTemplate = false
        statusItem.length = image.size.width
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.image = image
        // The status button turns colored images into a template mask unless
        // this is set on the image it actually retained.
        statusItem.button?.image?.isTemplate = false
        statusItem.isVisible = true
        statusItem.button?.toolTip = tooltip
    }

    @objc private func motionOptionsChanged(_ notification: Notification) {
        displayedKey = ""
        updateImage(force: true)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
