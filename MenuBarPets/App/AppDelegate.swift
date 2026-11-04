import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: PetStore?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let store = PetStore()
        let menuBar = MenuBarController(store: store)
        self.store = store
        self.menuBar = menuBar

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            menuBar.showGallery()
        }
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
    }
}
