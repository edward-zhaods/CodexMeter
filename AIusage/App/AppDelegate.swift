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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            controller.showMeterWindow()
            controller.showFloatingStatus()
        }

        Task {
            await state.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stop()
    }
}
