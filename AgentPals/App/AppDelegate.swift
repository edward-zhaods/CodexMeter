import AppKit

private let appDelegate = AppDelegate()

@main
enum AgentPalsMain {
    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = ActivityMonitor()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var snapshot = ActivitySnapshot()
    private var tick = 8
    private var frameTimer: Timer?
    private var displayedKey = ""
    private var claudeItem: NSMenuItem?
    private var codexItem: NSMenuItem?
    private var cursorItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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

        claudeItem = statusRow(title: "Claude")
        codexItem = statusRow(title: "Codex")
        cursorItem = statusRow(title: "Cursor")
        for item in [claudeItem, codexItem, cursorItem] {
            if let item {
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.accessibilityLabel = "AgentPals"
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
        claudeItem?.title = rowTitle("Claude", working: snapshot.claude)
        codexItem?.title = rowTitle("Codex", working: snapshot.codex)
        cursorItem?.title = rowTitle("Cursor", working: snapshot.cursor)
    }

    private func rowTitle(_ name: String, working: Bool) -> String {
        "\(name)：\(working ? "工作中" : "闲着")"
    }

    private var tooltip: String {
        "Claude \(stateWord(snapshot.claude)) · Codex \(stateWord(snapshot.codex)) · Cursor \(stateWord(snapshot.cursor))"
    }

    private func stateWord(_ working: Bool) -> String {
        working ? "工作中" : "闲着"
    }

    private func updateImage(force: Bool) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let key = PixelSprites.cacheKey(
            claudeWorking: snapshot.claude,
            codexWorking: snapshot.codex,
            cursorWorking: snapshot.cursor,
            tick: tick,
            reduceMotion: reduceMotion
        )
        guard force || key != displayedKey else { return }
        displayedKey = key

        let image = PixelSprites.image(
            claudeWorking: snapshot.claude,
            codexWorking: snapshot.codex,
            cursorWorking: snapshot.cursor,
            tick: tick,
            reduceMotion: reduceMotion
        )
        statusItem.button?.image = image
        statusItem.button?.toolTip = tooltip
        statusItem.button?.accessibilityValue = tooltip
    }

    @objc private func motionOptionsChanged(_ notification: Notification) {
        displayedKey = ""
        updateImage(force: true)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
