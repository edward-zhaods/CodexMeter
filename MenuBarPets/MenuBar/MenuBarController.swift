import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let store: PetStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var galleryWindow: NSWindow?
    private var animationTimer: Timer?
    private var petFrame = 0
    private var cancellables = Set<AnyCancellable>()

    init(store: PetStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePopover()
        bindState()
        startPetAnimation()
        updateStatusImage()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.title = ""
        button.image = PetArt.statusBarImage(moods: store.moods, bob: false)
        button.toolTip = "MenuBar Pets"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 320, height: 268)
        let host = NSHostingController(rootView: PetsMenuView(store: store))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePetSelect(_:)),
            name: .petsMenuSelect,
            object: nil
        )
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handlePetSelect(_ notification: Notification) {
        guard let rawValue = notification.object as? String, let kind = PetKind(rawValue: rawValue) else { return }
        store.focusedPet = kind
        popover.performClose(nil)
        showGallery()
    }

    private func bindState() {
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusImage()
                }
            }
            .store(in: &cancellables)
    }

    private func startPetAnimation() {
        animationTimer?.invalidate()
        let timer = Timer(
            timeInterval: 0.7,
            target: self,
            selector: #selector(advancePetFrame),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc private func advancePetFrame() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        petFrame &+= 1
        updateStatusImage()
    }

    private func updateStatusImage() {
        guard let button = statusItem.button else { return }
        let bob = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && petFrame.isMultiple(of: 2)
        button.image = PetArt.statusBarImage(moods: store.moods, bob: bob)
        button.imagePosition = .imageOnly
        button.title = ""
        button.toolTip = store.statusSummary()
    }

    func showGallery() {
        if let galleryWindow {
            galleryWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MenuBar Pets"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.11, alpha: 1)
        window.minSize = NSSize(width: 960, height: 680)
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: PetsGalleryView(store: store))
        window.center()
        galleryWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
