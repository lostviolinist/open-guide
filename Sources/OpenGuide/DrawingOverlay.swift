import AppKit
import SwiftUI
import GuideCore

@MainActor
final class DrawingOverlay {
    private var panel: NSPanel?
    func show(marks: [GuideMark], interaction: GuideInteraction?, region: CGRect) {
        hide()
        let panel = NSPanel(contentRect: region, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: DrawingCanvas(marks: marks, interaction: interaction))
        panel.orderFrontRegardless()
        self.panel = panel
    }
    func hide() { panel?.orderOut(nil); panel = nil }
}

struct DrawingCanvas: View {
    let marks: [GuideMark]
    let interaction: GuideInteraction?
    var body: some View {
        Canvas { context, size in
            for mark in marks {
                let color = color(for: mark.color)
                if mark.kind == .arrow, let start = mark.from, let end = mark.to {
                    let startPoint = CGPoint(x: CGFloat(start.x) * size.width, y: CGFloat(start.y) * size.height)
                    let endPoint = CGPoint(x: CGFloat(end.x) * size.width, y: CGFloat(end.y) * size.height)
                    var path = Path()
                    path.move(to: startPoint); path.addLine(to: endPoint)
                    let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
                    for offset: CGFloat in [-0.5, 0.5] {
                        path.move(to: endPoint)
                        path.addLine(to: CGPoint(x: endPoint.x - 17 * cos(angle + offset), y: endPoint.y - 17 * sin(angle + offset)))
                    }
                    context.stroke(path, with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                } else if let bounds = mark.rect {
                    let rect = CGRect(x: CGFloat(bounds.x) * size.width, y: CGFloat(bounds.y) * size.height,
                                      width: CGFloat(bounds.width) * size.width, height: CGFloat(bounds.height) * size.height)
                    let path = Path(roundedRect: rect, cornerRadius: 10)
                    if mark.kind == .highlight {
                        context.fill(path, with: .color(color.opacity(0.13)))
                        context.stroke(path, with: .color(.black.opacity(0.6)), lineWidth: 6)
                        context.stroke(path, with: .color(color), lineWidth: 3)
                    } else if let text = mark.text {
                        context.fill(path, with: .color(Color(red: 0.06, green: 0.1, blue: 0.14).opacity(0.96)))
                        context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 1)
                        context.draw(Text(text).font(.system(size: min(18, max(11, rect.height * 0.3)), weight: .semibold)).foregroundColor(color), in: rect.insetBy(dx: 8, dy: 4))
                    }
                }
            }
            if let interaction {
                let target = interaction.target
                let rect = CGRect(x: CGFloat(target.x) * size.width, y: CGFloat(target.y) * size.height,
                                  width: CGFloat(target.width) * size.width, height: CGFloat(target.height) * size.height)
                context.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(.orange),
                               style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    private func color(for color: GuideColor) -> Color {
        switch color { case .mint: return .mint; case .amber: return .orange; case .blue: return .cyan }
    }
}

@MainActor
final class DemoStage {
    private var window: NSWindow?
    func show() -> CGRect {
        close()
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let size = CGSize(width: min(700, screen.visibleFrame.width - 80), height: min(470, screen.visibleFrame.height - 100))
        let origin = CGPoint(x: screen.visibleFrame.minX + 35, y: screen.visibleFrame.midY - size.height / 2)
        let window = NSWindow(contentRect: CGRect(origin: origin, size: size),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "OpenGuide · Local playground"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: DemoStageView())
        window.makeKeyAndOrderFront(nil)
        self.window = window
        return window.convertToScreen(window.contentView!.bounds)
    }
    func close() { window?.orderOut(nil); window = nil }
}

private struct DemoStageView: View {
    @State private var hovering = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.055, green: 0.08, blue: 0.11)
                VStack(alignment: .leading, spacing: 14) {
                    Text("A clearer view.").font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("Explanations that live alongside your work.").font(.title3).foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        Label("See", systemImage: "viewfinder")
                        Label("Understand", systemImage: "sparkles")
                        Label("Try", systemImage: "cursorarrow")
                    }.font(.system(size: 15, weight: .medium)).foregroundStyle(.mint)
                }
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.35)
                Button {} label: {
                    Text(hovering ? "New context revealed ✓" : "Hover to explore")
                        .font(.headline)
                        .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.16)
                        .background(hovering ? Color.mint.opacity(0.25) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Demo hover target")
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.76)
                .onHover { inside in
                    hovering = inside
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                Text("LOCAL DEMO  /  NO SCREEN CAPTURE  /  NO NETWORK")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.94)
            }
        }
        .preferredColorScheme(.dark)
    }
}
