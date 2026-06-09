import AppKit

struct WindowInfo: Equatable {
    let frame: CGRect          // sheet "Arrange Displays" (target overlay), coordinate AX
    let canvas: CGRect?        // gruppo "Arrangement View", coordinate AX
    let displays: [CGRect]     // rettangoli dei monitor (AXImage), coordinate AX

    private func k(_ r: CGRect) -> String {
        "\(Int(r.origin.x)),\(Int(r.origin.y)),\(Int(r.size.width)),\(Int(r.size.height))"
    }

    private var key: String {
        let c = canvas.map(k) ?? "nil"
        let d = displays.map(k).joined(separator: ";")
        return "\(k(frame))|\(c)|\(d)"
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.key == rhs.key
    }
}

final class ForegroundWindowWatcher {
    typealias Handler = (WindowInfo?) -> Void

    private let handler: Handler
    private var timer: Timer?
    private var lastInfo: WindowInfo?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private struct Target {
        let frame: CGRect
        let canvas: CGRect?
        let displays: [CGRect]
    }

    private func tick() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            emitIfChanged(nil)
            return
        }

        let bundleID = app.bundleIdentifier
        let isSettingsApp = bundleID == "com.apple.systempreferences" || bundleID == "com.apple.SystemSettings"
        guard isSettingsApp else {
            emitIfChanged(nil)
            return
        }

        // L'overlay serve solo quando lo sheet "Arrange Displays" è aperto e contiene monitor.
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let target = findArrangeTarget(axApp: axApp), !target.displays.isEmpty else {
            emitIfChanged(nil)
            return
        }

        emitIfChanged(WindowInfo(frame: target.frame, canvas: target.canvas, displays: target.displays))
    }

    // Cerca lo sheet/finestra "Arrange Displays" tra le finestre dell'app e ne estrae i monitor.
    private func findArrangeTarget(axApp: AXUIElement) -> Target? {
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return nil
        }

        for window in windows {
            let title = readStringAttribute(window: window, attribute: kAXTitleAttribute)
            if matchesArrange(title), let frame = readFrame(window: window) {
                let arr = collectArrangement(in: window)
                return Target(frame: frame, canvas: arr.canvas, displays: arr.displays)
            }
            if let sheet = firstSheet(in: window), let frame = readFrame(window: sheet) {
                let arr = collectArrangement(in: sheet)
                if !arr.displays.isEmpty {
                    return Target(frame: frame, canvas: arr.canvas, displays: arr.displays)
                }
            }
        }
        return nil
    }

    private func firstSheet(in window: AXUIElement) -> AXUIElement? {
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }
        return children.first { readStringAttribute(window: $0, attribute: kAXRoleAttribute) == (kAXSheetRole as String) }
    }

    // Il canvas è il gruppo "Arrangement View"; i monitor sono gli AXImage al suo interno.
    private func collectArrangement(in element: AXUIElement) -> (canvas: CGRect?, displays: [CGRect]) {
        let canvasGroup = findDescendant(in: element, depth: 0) {
            self.readStringAttribute(window: $0, attribute: kAXDescriptionAttribute) == "Arrangement View"
        }
        let canvas = canvasGroup.flatMap { readFrame(window: $0) }
        let root = canvasGroup ?? element  // fallback robusto alla localizzazione
        var displays: [CGRect] = []
        collectImageFrames(in: root, depth: 0, into: &displays)
        return (canvas, displays)
    }

    private func findDescendant(in element: AXUIElement, depth: Int, where predicate: (AXUIElement) -> Bool) -> AXUIElement? {
        if depth > 10 { return nil }
        if predicate(element) { return element }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }
        for child in children {
            if let found = findDescendant(in: child, depth: depth + 1, where: predicate) { return found }
        }
        return nil
    }

    private func collectImageFrames(in element: AXUIElement, depth: Int, into result: inout [CGRect]) {
        if depth > 10 { return }
        if readStringAttribute(window: element, attribute: kAXRoleAttribute) == (kAXImageRole as String),
           let frame = readFrame(window: element) {
            result.append(frame)
        }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return
        }
        for child in children {
            collectImageFrames(in: child, depth: depth + 1, into: &result)
        }
    }

    private func matchesArrange(_ text: String?) -> Bool {
        guard let t = text?.lowercased() else { return false }
        return t.contains("arrange") || t.contains("disponi")
    }

    private func emitIfChanged(_ info: WindowInfo?) {
        if info != lastInfo {
            lastInfo = info
            handler(info)
        }
    }

    private func readStringAttribute(window: CFTypeRef, attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window as! AXUIElement, attribute as CFString, &value)
        guard result == .success, let str = value as? String else {
            return nil
        }
        return str
    }

    private func readFrame(window: CFTypeRef) -> CGRect? {
        guard let position = readPointAttribute(window: window, attribute: kAXPositionAttribute),
              let size = readSizeAttribute(window: window, attribute: kAXSizeAttribute) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func readPointAttribute(window: CFTypeRef, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window as! AXUIElement, attribute as CFString, &value)
        guard result == .success, let value else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    private func readSizeAttribute(window: CFTypeRef, attribute: String) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window as! AXUIElement, attribute as CFString, &value)
        guard result == .success, let value else {
            return nil
        }
        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }
}
