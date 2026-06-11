import AppKit

final class GuideOverlayView: NSView {
    var displays: [CGRect] = []
    var canvas: CGRect?

    // Tolleranza (in punti del canvas) entro cui due centri sono considerati allineati.
    // Tenuta stretta: il canvas di Arrange è molto rimpicciolito, quindi 1pt ≈ ~13px reali.
    private let alignTolerance: CGFloat = 1

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        drawAlignmentLines(scale: scale)
        drawEdgeLines(scale: scale)
        drawOffsetBadges()
    }

    // Guide attraverso il centro di ogni schermo:
    // - schermo singolo non allineato: croce sottile (alpha 0.5) contenuta nei suoi bordi.
    // - centri allineati tra più schermi: linea piena (alpha 1.0) e più spessa estesa a tutto il canvas.
    private func drawAlignmentLines(scale: CGFloat) {
        guard !displays.isEmpty else { return }
        let canvasY = verticalSpan()
        let canvasX = horizontalSpan()

        for g in groupDisplays(by: { $0.midX }) {
            let x = aligned(g.value, scale: scale)
            let range: ClosedRange<CGFloat> = g.rects.count >= 2
                ? canvasY
                : g.rects[0].minY...g.rects[0].maxY
            drawLine(from: CGPoint(x: x, y: range.lowerBound),
                     to: CGPoint(x: x, y: range.upperBound),
                     highlighted: g.rects.count >= 2)
        }

        for g in groupDisplays(by: { $0.midY }) {
            let y = aligned(g.value, scale: scale)
            let range: ClosedRange<CGFloat> = g.rects.count >= 2
                ? canvasX
                : g.rects[0].minX...g.rects[0].maxX
            drawLine(from: CGPoint(x: range.lowerBound, y: y),
                     to: CGPoint(x: range.upperBound, y: y),
                     highlighted: g.rects.count >= 2)
        }
    }

    private func drawLine(from a: CGPoint, to b: CGPoint, highlighted: Bool) {
        NSColor.controlAccentColor.withAlphaComponent(highlighted ? 1.0 : 0.5).setStroke()
        let path = NSBezierPath()
        path.lineWidth = highlighted ? 2.0 : 1.0
        path.move(to: a)
        path.line(to: b)
        path.stroke()
    }

    // Guide sui bordi (stile Figma): linea tratteggiata quando i bordi omologhi
    // (top/top, bottom/bottom, left/left, right/right) di ≥2 schermi coincidono.
    // Nessuna guida permanente sui bordi: appaiono solo all'allineamento.
    private func drawEdgeLines(scale: CGFloat) {
        guard displays.count >= 2 else { return }
        let canvasY = verticalSpan()
        let canvasX = horizontalSpan()

        let verticalEdges: [(CGRect) -> CGFloat] = [{ $0.minX }, { $0.maxX }]
        for key in verticalEdges {
            for g in groupDisplays(by: key) where g.rects.count >= 2 {
                let x = aligned(g.value, scale: scale)
                drawDashedLine(from: CGPoint(x: x, y: canvasY.lowerBound),
                               to: CGPoint(x: x, y: canvasY.upperBound))
            }
        }

        let horizontalEdges: [(CGRect) -> CGFloat] = [{ $0.minY }, { $0.maxY }]
        for key in horizontalEdges {
            for g in groupDisplays(by: key) where g.rects.count >= 2 {
                let y = aligned(g.value, scale: scale)
                drawDashedLine(from: CGPoint(x: canvasX.lowerBound, y: y),
                               to: CGPoint(x: canvasX.upperBound, y: y))
            }
        }
    }

    private func drawDashedLine(from a: CGPoint, to b: CGPoint) {
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.setLineDash([5, 3], count: 2, phase: 0)
        path.move(to: a)
        path.line(to: b)
        path.stroke()
    }

    // Badge "Δx ≈ N px" quando i centri di due schermi sono vicini all'allineamento
    // ma non ancora allineati. La conversione punti→pixel reali sfrutta il fatto che
    // il canvas di Arrange usa una scala uniforme per tutti gli schermi.
    private func drawOffsetBadges() {
        guard displays.count >= 2 else { return }
        let pxPerPoint = estimatedPixelsPerPoint()
        let nearThreshold: CGFloat = 30

        for i in 0..<displays.count {
            for j in (i + 1)..<displays.count {
                let c1 = CGPoint(x: displays[i].midX, y: displays[i].midY)
                let c2 = CGPoint(x: displays[j].midX, y: displays[j].midY)
                let dx = abs(c1.x - c2.x)
                let dy = abs(c1.y - c2.y)

                var parts: [String] = []
                if dx > alignTolerance && dx <= nearThreshold {
                    parts.append("Δx ≈ \(Int((dx * pxPerPoint).rounded())) px")
                }
                if dy > alignTolerance && dy <= nearThreshold {
                    parts.append("Δy ≈ \(Int((dy * pxPerPoint).rounded())) px")
                }
                guard !parts.isEmpty else { continue }

                let mid = CGPoint(x: (c1.x + c2.x) / 2, y: (c1.y + c2.y) / 2)
                drawBadge(parts.joined(separator: "   "), centeredAt: CGPoint(x: mid.x, y: mid.y + 14))
            }
        }
    }

    private func drawBadge(_ text: String, centeredAt point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let padding = CGSize(width: 7, height: 3)
        var rect = CGRect(
            x: point.x - size.width / 2 - padding.width,
            y: point.y - size.height / 2 - padding.height,
            width: size.width + padding.width * 2,
            height: size.height + padding.height * 2
        )
        // Tieni il badge dentro la vista.
        rect.origin.x = max(2, min(rect.origin.x, bounds.maxX - rect.width - 2))
        rect.origin.y = max(2, min(rect.origin.y, bounds.maxY - rect.height - 2))

        let capsule = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.controlAccentColor.withAlphaComponent(0.95).setFill()
        capsule.fill()
        text.draw(at: CGPoint(x: rect.minX + padding.width, y: rect.minY + padding.height), withAttributes: attributes)
    }

    private func estimatedPixelsPerPoint() -> CGFloat {
        let realMaxWidth = NSScreen.screens.map { $0.frame.width * $0.backingScaleFactor }.max() ?? 0
        let miniatureMaxWidth = displays.map { $0.width }.max() ?? 0
        guard realMaxWidth > 0, miniatureMaxWidth > 0 else { return 1 }
        return realMaxWidth / miniatureMaxWidth
    }

    private struct DisplayGroup {
        var value: CGFloat
        var rects: [CGRect]
    }

    // Raggruppa gli schermi per coordinata (midX o midY) entro la tolleranza.
    private func groupDisplays(by key: (CGRect) -> CGFloat) -> [DisplayGroup] {
        var groups: [DisplayGroup] = []
        for rect in displays {
            let v = key(rect)
            if let i = groups.firstIndex(where: { abs($0.value - v) <= alignTolerance }) {
                let total = groups[i].value * CGFloat(groups[i].rects.count) + v
                groups[i].rects.append(rect)
                groups[i].value = total / CGFloat(groups[i].rects.count)
            } else {
                groups.append(DisplayGroup(value: v, rects: [rect]))
            }
        }
        return groups
    }

    private func verticalSpan() -> ClosedRange<CGFloat> {
        if let canvas { return canvas.minY...canvas.maxY }
        let minY = displays.map { $0.minY }.min() ?? bounds.minY
        let maxY = displays.map { $0.maxY }.max() ?? bounds.maxY
        return (minY - 16)...(maxY + 16)
    }

    private func horizontalSpan() -> ClosedRange<CGFloat> {
        if let canvas { return canvas.minX...canvas.maxX }
        let minX = displays.map { $0.minX }.min() ?? bounds.minX
        let maxX = displays.map { $0.maxX }.max() ?? bounds.maxX
        return (minX - 16)...(maxX + 16)
    }

    private func aligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (floor(value * scale) + 0.5) / scale
    }
}
