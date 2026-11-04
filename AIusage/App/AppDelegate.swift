import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = AppState()
        let controller = MenuBarController(appState: state)
        appState = state
        menuBarController = controller

        Task {
            await state.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stop()
    }
}
