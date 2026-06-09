import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var watcher: ForegroundWindowWatcher?
    private let overlayController = GuideOverlayController()
    private let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = AppIcon.image(size: 512)
        menuBar.install()
        requestAccessibilityIfNeeded()

        Log.write("applicationDidFinishLaunching")
        watcher = ForegroundWindowWatcher { [weak self] info in
            self?.handleWindowInfo(info)
        }
        watcher?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            NSLog("Accessibility permission not granted yet.")
        }
    }

    private func handleWindowInfo(_ info: WindowInfo?) {
        guard let info else {
            overlayController.hide()
            return
        }
        overlayController.show(sheet: info.frame, canvas: info.canvas, displays: info.displays)
    }
}
