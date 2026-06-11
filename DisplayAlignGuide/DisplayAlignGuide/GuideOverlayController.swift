import AppKit

final class GuideOverlayController {
    private var overlayWindow: NonActivatingPanel?
    private var overlayView: GuideOverlayView?
    private var isShown = false

    func show(sheet axSheet: CGRect, canvas axCanvas: CGRect?, displays axDisplays: [CGRect]) {
        DispatchQueue.main.async {
            let windowRect = self.cocoaRect(fromAX: axSheet)
            if self.overlayWindow == nil {
                self.createOverlayWindow(frame: windowRect)
            }
            guard let panel = self.overlayWindow else { return }
            panel.setFrame(windowRect, display: false)

            let origin = windowRect.origin
            self.overlayView?.displays = axDisplays.map { self.toLocal(self.cocoaRect(fromAX: $0), origin: origin) }
            self.overlayView?.canvas = axCanvas.map { self.toLocal(self.cocoaRect(fromAX: $0), origin: origin) }
            self.overlayView?.needsDisplay = true

            if !self.isShown {
                self.isShown = true
                panel.alphaValue = 0
                panel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.12
                    panel.animator().alphaValue = 1
                }
            } else {
                // Annulla un eventuale fade-out in corso.
                panel.animator().alphaValue = 1
                panel.orderFrontRegardless()
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            guard self.isShown, let panel = self.overlayWindow else { return }
            self.isShown = false
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.10
                panel.animator().alphaValue = 0
            }, completionHandler: {
                // Se nel frattempo è ripartito uno show, non nascondere.
                if !self.isShown {
                    panel.orderOut(nil)
                }
            })
        }
    }

    private func createOverlayWindow(frame: CGRect) {
        let panel = NonActivatingPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false

        let view = GuideOverlayView(frame: CGRect(origin: .zero, size: frame.size))
        view.autoresizingMask = [.width, .height]
        panel.contentView = view

        self.overlayWindow = panel
        self.overlayView = view
    }

    // AXPosition usa origine in alto-sinistra (Y verso il basso); NSWindow.setFrame
    // usa origine in basso-sinistra (Y verso l'alto). Ribalta rispetto allo schermo primario.
    private func cocoaRect(fromAX axRect: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return axRect }
        let y = primary.frame.height - axRect.origin.y - axRect.height
        return CGRect(x: axRect.origin.x, y: y, width: axRect.width, height: axRect.height)
    }

    // Da coordinate Cocoa globali a coordinate locali della contentView dell'overlay.
    private func toLocal(_ rect: CGRect, origin: CGPoint) -> CGRect {
        CGRect(x: rect.origin.x - origin.x, y: rect.origin.y - origin.y, width: rect.width, height: rect.height)
    }
}

final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
