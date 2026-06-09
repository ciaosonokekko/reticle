import AppKit

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let accessibilityItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let symbol = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Reticle") {
                symbol.isTemplate = true
                button.image = symbol
            } else {
                button.title = "Reticle"
            }
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(makeItem("Open Arrange Displays", #selector(openArrange)))

        accessibilityItem.action = #selector(checkAccessibility)
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())
        menu.addItem(makeItem("About Reticle", #selector(showAbout)))
        menu.addItem(makeItem("Quit", #selector(quit), key: "q"))

        item.menu = menu
        statusItem = item
        updateAccessibilityItem()

        // L'icona è un bitmap: va rigenerata quando l'utente cambia l'accent color del sistema.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshIcon),
            name: NSNotification.Name("NSSystemColorsDidChangeNotification"),
            object: nil
        )
        refreshIcon()
    }

    @objc private func refreshIcon() {
        NSApp.applicationIconImage = AppIcon.image(size: 512)
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateAccessibilityItem()
    }

    private func updateAccessibilityItem() {
        accessibilityItem.title = AXIsProcessTrusted() ? "Accessibility: granted ✓" : "Grant Accessibility…"
    }

    @objc private func openArrange() {
        SystemSettingsControl.openArrangeDisplays()
    }

    @objc private func checkAccessibility() {
        NSApp.activate(ignoringOtherApps: true)

        if AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility already granted"
            alert.informativeText = "Reticle has the required permissions. The overlay is active."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            updateAccessibilityItem()
            return
        }

        // The system prompt adds the app to the Accessibility list (disabled) and shows macOS's dialog.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = "Enable Reticle in Accessibility"
        alert.informativeText = """
        Reticle needs Accessibility permission to draw alignment guides.

        1. Open System Settings → Privacy & Security → Accessibility.
        2. Find “Reticle” in the list — it has already been added.
        3. Flip its toggle on.

        You don't need to browse or drag the app: it's already there, just enable it.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        updateAccessibilityItem()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let credits = NSAttributedString(
            string: "Alignment guides for the macOS Arrange Displays sheet.\nLights up an accent-colored line when two displays' centers align.",
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Reticle",
            .applicationVersion: version,
            .credits: credits
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

enum SystemSettingsControl {
    static func openArrangeDisplays() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Displays-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.displays"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { break }
        }
        // L'apertura del pannello non mostra direttamente Arrange: premiamo il bottone via AX appena disponibile.
        pressArrange(attemptsLeft: 15)
    }

    private static func pressArrange(attemptsLeft: Int) {
        guard attemptsLeft > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if findAndPressArrange() { return }
            pressArrange(attemptsLeft: attemptsLeft - 1)
        }
    }

    private static func findAndPressArrange() -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.systempreferences" || $0.bundleIdentifier == "com.apple.SystemSettings"
        }) else { return false }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return false
        }
        for window in windows {
            if let button = findArrangeButton(in: window, depth: 0) {
                AXUIElementPerformAction(button, kAXPressAction as CFString)
                return true
            }
        }
        return false
    }

    private static func findArrangeButton(in element: AXUIElement, depth: Int) -> AXUIElement? {
        if depth > 14 { return nil }
        if copyString(element, kAXRoleAttribute) == (kAXButtonRole as String) {
            let label = ((copyString(element, kAXTitleAttribute) ?? "") + " " + (copyString(element, kAXDescriptionAttribute) ?? "")).lowercased()
            if label.contains("arrange") || label.contains("disponi") {
                return element
            }
        }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }
        for child in children {
            if let found = findArrangeButton(in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    private static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}

enum AppIcon {
    private static let screenColor = NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.14, alpha: 1)

    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        // Sfondo arrotondato con gradiente grafite.
        let full = NSRect(x: 0, y: 0, width: size, height: size)
        let background = NSBezierPath(roundedRect: full, xRadius: size * 0.22, yRadius: size * 0.22)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.30, alpha: 1),
            NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1)
        ])?.draw(in: background, angle: -90)

        let cx = size / 2
        let bodyW = size * 0.66, bodyH = size * 0.50
        let body = CGRect(x: cx - bodyW / 2, y: size * 0.58 - bodyH / 2, width: bodyW, height: bodyH)

        let silver = NSGradient(colors: [
            NSColor(calibratedWhite: 0.92, alpha: 1),
            NSColor(calibratedWhite: 0.72, alpha: 1)
        ])

        // Piedistallo: collo + base (argento).
        silver?.draw(in: NSBezierPath(roundedRect: CGRect(x: cx - size * 0.05, y: body.minY - size * 0.085, width: size * 0.10, height: size * 0.10), xRadius: size * 0.015, yRadius: size * 0.015), angle: -90)
        silver?.draw(in: NSBezierPath(roundedRect: CGRect(x: cx - size * 0.14, y: body.minY - size * 0.105, width: size * 0.28, height: size * 0.035), xRadius: size * 0.017, yRadius: size * 0.017), angle: -90)

        // Corpo monitor (cornice argento) + schermo scuro.
        silver?.draw(in: NSBezierPath(roundedRect: body, xRadius: size * 0.05, yRadius: size * 0.05), angle: -90)
        let screen = body.insetBy(dx: size * 0.035, dy: size * 0.035)
        screenColor.setFill()
        NSBezierPath(roundedRect: screen, xRadius: size * 0.03, yRadius: size * 0.03).fill()

        // Mirino di centratura verde sullo schermo.
        drawReticle(in: screen, size: size)

        return image
    }

    private static func drawReticle(in screen: CGRect, size: CGFloat) {
        let cx = screen.midX, cy = screen.midY
        let lineWidth = size * 0.016
        let pad = size * 0.03

        NSColor.controlAccentColor.setStroke()
        let vertical = NSBezierPath()
        vertical.lineWidth = lineWidth
        vertical.move(to: CGPoint(x: cx, y: screen.minY + pad))
        vertical.line(to: CGPoint(x: cx, y: screen.maxY - pad))
        vertical.stroke()

        let horizontal = NSBezierPath()
        horizontal.lineWidth = lineWidth
        horizontal.move(to: CGPoint(x: screen.minX + pad, y: cy))
        horizontal.line(to: CGPoint(x: screen.maxX - pad, y: cy))
        horizontal.stroke()

        let r = size * 0.055
        let ring = NSBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        ring.lineWidth = lineWidth
        screenColor.setFill()
        ring.fill()
        NSColor.controlAccentColor.setStroke()
        ring.stroke()

        let dr = size * 0.016
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: CGRect(x: cx - dr, y: cy - dr, width: 2 * dr, height: 2 * dr)).fill()
    }
}
