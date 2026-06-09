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
