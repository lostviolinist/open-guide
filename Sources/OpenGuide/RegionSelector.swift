import AppKit

@MainActor
final class RegionSelector {
    private var panels: [NSPanel] = []
    private var completion: ((ScreenSelection?) -> Void)?
    func begin(completion: @escaping (ScreenSelection?) -> Void) {
        cancel()
        self.completion = completion
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let panel = SelectionPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onSelection = { [weak self] localRect in
                guard let self else { return }
                let result: ScreenSelection?
                if let localRect, let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    result = ScreenSelection(displayID: displayID, displayFrame: screen.frame,
                        region: localRect.offsetBy(dx: screen.frame.minX, dy: screen.frame.minY))
                } else { result = nil }
                self.finish(result)
            }
            panel.contentView = view
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(view)
            panels.append(panel)
        }
    }
    func cancel() { finish(nil) }
    private func finish(_ selection: ScreenSelection?) {
        let callback = completion
        completion = nil
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        callback?(selection)
    }
}
private final class SelectionPanel: NSPanel { override var canBecomeKey: Bool { true } }
private final class SelectionView: NSView {
    var onSelection: ((CGRect?) -> Void)?
    private var startPoint: CGPoint?
    private var selection = CGRect.zero
    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onSelection?(nil) }
    }
    override func mouseDown(with event: NSEvent) { startPoint = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(startPoint.x, point.x), y: min(startPoint.y, point.y),
                           width: abs(point.x - startPoint.x), height: abs(point.y - startPoint.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        onSelection?(selection.width >= 40 && selection.height >= 40 ? selection : nil)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()
        if !selection.isEmpty {
            NSColor.clear.setFill()
            selection.fill(using: .copy)
            NSColor.systemMint.setStroke()
            let outline = NSBezierPath(roundedRect: selection, xRadius: 5, yRadius: 5)
            outline.lineWidth = 3
            outline.stroke()
        }
        let text = "Drag to select a region · Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: NSColor.white]
        text.draw(at: CGPoint(x: 40, y: bounds.height - 80), withAttributes: attributes)
    }
}
