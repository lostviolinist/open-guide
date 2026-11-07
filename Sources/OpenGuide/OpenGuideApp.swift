import AppKit
import SwiftUI

@main
struct OpenGuideApp: App {
    @NSApplicationDelegateAdaptor(OpenGuideAppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class OpenGuideAppDelegate: NSObject, NSApplicationDelegate {
    private let session = GuideSession()
    private var statusItem: NSStatusItem?
    private var controlWindow: NSWindow?
    private var shortcut: SelectionShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "OpenGuide")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showControls)
        self.statusItem = statusItem
        session.onShowControls = { [weak self] in self?.showControls() }
        session.onHideControls = { [weak self] in self?.controlWindow?.orderOut(nil) }
        shortcut = SelectionShortcut { [weak self] in self?.session.selectRegion() }
        showControls()
        if CommandLine.arguments.contains("--demo") { session.startDemo() }
    }
    @objc private func showControls() {
        if controlWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 460, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "OpenGuide"
            window.contentView = NSHostingView(rootView: GuideControlView(session: session))
            window.minSize = NSSize(width: 430, height: 560)
            window.isReleasedWhenClosed = false
            if let screen = NSScreen.main {
                window.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX - 480, y: screen.visibleFrame.maxY - 740))
            }
            controlWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        controlWindow?.makeKeyAndOrderFront(nil)
    }
    func applicationWillTerminate(_ notification: Notification) { session.stop() }
}
