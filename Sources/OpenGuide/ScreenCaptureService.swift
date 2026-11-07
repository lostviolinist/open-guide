// Adapted from farzaa/clicky's MIT-licensed CompanionScreenCaptureUtility.swift.
// See LICENSE and PROVENANCE.md. OpenGuide captures only the explicit selection.
import AppKit
import ScreenCaptureKit

struct ScreenSelection {
    let displayID: CGDirectDisplayID
    let displayFrame: CGRect
    let region: CGRect
}

@MainActor
enum ScreenCaptureService {
    static func capture(_ selection: ScreenSelection) async throws -> Data {
        guard #available(macOS 14.2, *) else { throw GuideAppError("Screen capture requires macOS 14.2 or later.") }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == selection.displayID }),
              let screen = NSScreen.screens.first(where: {
                  ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == selection.displayID
              }), screen.frame == selection.displayFrame else {
            throw GuideAppError("Your display layout changed. Select the region again.")
        }
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let configuration = SCStreamConfiguration()
        let region = selection.region
        configuration.sourceRect = CGRect(x: region.minX - screen.frame.minX,
                                          y: screen.frame.maxY - region.maxY,
                                          width: region.width, height: region.height)
        let scale = min(2, 1600 / max(region.width, region.height))
        configuration.width = max(1, Int(region.width * scale))
        configuration.height = max(1, Int(region.height * scale))
        configuration.showsCursor = false
        let capture = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let image = NSBitmapImageRep(cgImage: capture).representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw GuideAppError("Could not encode the selected region.")
        }
        return image
    }
}

struct GuideAppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
