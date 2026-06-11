import AppKit

// Lowercased substrings that identify the "Arrange…" control across locales (EN/IT/FR/ES/DE).
enum ArrangeKeywords {
    static let all = ["arrange", "disponi", "disposer", "organiser", "organizar", "disponer", "anordnen"]
}

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

    // Polling adattivo: lento quando l'overlay è nascosto, veloce quando è visibile
    // così la chiusura dello sheet viene rilevata entro ~50ms (niente guide "orfane").
    private let idleInterval: TimeInterval = 0.15
    private let activeInterval: TimeInterval = 0.05
    private var currentInterval: TimeInterval = 0

    func start() {
        reschedule(interval: idleInterval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentInterval = 0
    }

    private func reschedule(interval: TimeInterval) {
        guard interval != currentInterval else { return }
        timer?.invalidate()
        currentInterval = interval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
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

    // Rilevamento language-independent: il canvas di disposizione è l'AXGroup che
    // contiene il maggior numero di AXImage (i monitor). Nessuna stringa localizzata.
    private func collectArrangement(in element: AXUIElement) -> (canvas: CGRect?, displays: [CGRect]) {
        var best: (group: AXUIElement, frame: CGRect, images: [CGRect])?
        scanGroups(in: element, depth: 0) { group in
            guard let frame = self.readFrame(window: group) else { return }
            var images: [CGRect] = []
            self.collectImageFrames(in: group, depth: 0, into: &images)
            guard !images.isEmpty else { return }
            // Preferisci il gruppo con più immagini; a parità, l'area minore (canvas più stretto).
            if let current = best {
                let better = images.count > current.images.count ||
                    (images.count == current.images.count && frame.width * frame.height < current.frame.width * current.frame.height)
                if better { best = (group, frame, images) }
            } else {
                best = (group, frame, images)
            }
        }

        if let best {
            return (best.frame, best.images)
        }
        // Fallback: nessun gruppo con immagini → scansiona l'intero sottoalbero.
        var displays: [CGRect] = []
        collectImageFrames(in: element, depth: 0, into: &displays)
        return (nil, displays)
    }

    private func scanGroups(in element: AXUIElement, depth: Int, visit: (AXUIElement) -> Void) {
        if depth > 12 { return }
        if readStringAttribute(window: element, attribute: kAXRoleAttribute) == (kAXGroupRole as String) {
            visit(element)
        }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return
        }
        for child in children {
            scanGroups(in: child, depth: depth + 1, visit: visit)
        }
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
        // EN / IT / FR / ES / DE keywords (best-effort; the sheet path is role-based and language-agnostic).
        return ArrangeKeywords.all.contains { t.contains($0) }
    }

    private func emitIfChanged(_ info: WindowInfo?) {
        if info != lastInfo {
            lastInfo = info
            handler(info)
        }
        reschedule(interval: info != nil ? activeInterval : idleInterval)
    }

    // Safe downcast: returns nil instead of crashing if the CF object isn't an AXUIElement.
    private func asElement(_ ref: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    private func readStringAttribute(window: CFTypeRef, attribute: String) -> String? {
        guard let element = asElement(window) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let str = value as? String else {
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
        guard let element = asElement(window) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func readSizeAttribute(window: CFTypeRef, attribute: String) -> CGSize? {
        guard let element = asElement(window) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
