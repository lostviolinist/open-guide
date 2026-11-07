import CoreGraphics
import Foundation

public struct GuideProtocolError: LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct GuidePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public var isValid: Bool { x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y) }
}

public struct GuideRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 &&
        width > 0 && height > 0 && x + width <= 1.000001 && y + height <= 1.000001
    }
    public func contains(_ point: GuidePoint) -> Bool {
        point.x >= x && point.x <= x + width && point.y >= y && point.y <= y + height
    }
    /// Converts top-left normalized protocol coordinates into global AppKit coordinates.
    public func appKitFrame(in region: CGRect) -> CGRect {
        let originX: CGFloat = region.minX + CGFloat(self.x) * region.width
        let originY: CGFloat = region.maxY - CGFloat(self.y + self.height) * region.height
        let mappedWidth: CGFloat = CGFloat(self.width) * region.width
        let mappedHeight: CGFloat = CGFloat(self.height) * region.height
        let origin = CGPoint(x: originX, y: originY)
        let size = CGSize(width: mappedWidth, height: mappedHeight)
        return CGRect(origin: origin, size: size)
    }
}

public enum GuideMarkKind: String, Codable, Sendable { case highlight, arrow, label }
public enum GuideColor: String, Codable, Sendable { case mint, amber, blue }
public struct GuideMark: Codable, Equatable, Sendable {
    public let id: String
    public let kind: GuideMarkKind
    public let color: GuideColor
    public let rect: GuideRect?
    public let from: GuidePoint?
    public let to: GuidePoint?
    public let text: String?
}
public enum GuideInteractionKind: String, Codable, Sendable { case hover, click }
public struct GuideInteraction: Codable, Equatable, Sendable {
    public let kind: GuideInteractionKind
    public let target: GuideRect
    public let label: String
    public let dwellMilliseconds: Int
}
public struct GuideStep: Codable, Equatable, Sendable {
    public let id: String
    public let narration: String
    public let marks: [GuideMark]
    public let interaction: GuideInteraction?
}
public struct GuideDocument: Codable, Equatable, Sendable {
    public let version: Int
    public let title: String
    public let steps: [GuideStep]

    public static func decode(_ data: Data) throws -> GuideDocument {
        guard data.count <= 256_000 else { throw GuideProtocolError("The explanation exceeds 256 KB.") }
        let document = try JSONDecoder().decode(GuideDocument.self, from: data)
        try document.validate()
        return document
    }
    public func validate() throws {
        guard version == 1 else { throw GuideProtocolError("Unsupported drawing protocol version.") }
        guard !title.isEmpty, title.count <= 120, (1...12).contains(steps.count) else {
            throw GuideProtocolError("An explanation needs a title and 1–12 steps.")
        }
        var identifiers = Set<String>()
        for (stepIndex, step) in steps.enumerated() {
            guard !step.id.isEmpty, step.id.count <= 80, identifiers.insert(step.id).inserted,
                  !step.narration.isEmpty, step.narration.count <= 1200, step.marks.count <= 20 else {
                throw GuideProtocolError("Invalid or duplicate step, oversized narration, or too many marks.")
            }
            var markIdentifiers = Set<String>()
            for mark in step.marks {
                guard !mark.id.isEmpty, mark.id.count <= 80, markIdentifiers.insert(mark.id).inserted,
                      (mark.text?.count ?? 0) <= 160 else { throw GuideProtocolError("Invalid drawing mark.") }
                switch mark.kind {
                case .highlight, .label:
                    guard mark.rect?.isValid == true else { throw GuideProtocolError("Drawing bounds must fit the selected region.") }
                    if mark.kind == .label && (mark.text?.isEmpty != false) { throw GuideProtocolError("A label needs text.") }
                case .arrow:
                    guard mark.from?.isValid == true, mark.to?.isValid == true, mark.from != mark.to else {
                        throw GuideProtocolError("An arrow needs two distinct points inside the selection.")
                    }
                }
            }
            if let interaction = step.interaction {
                guard stepIndex == steps.count - 1, interaction.target.isValid,
                      !interaction.label.isEmpty, interaction.label.count <= 160,
                      (300...3000).contains(interaction.dwellMilliseconds) else {
                    throw GuideProtocolError("Only the last step can wait for a bounded hover/click target (300–3000 ms).")
                }
            }
        }
    }
}

/// A monotonic-clock gate. Leaving a target resets dwell; clicks require a new press.
public struct InteractionGate {
    private var enteredAt: TimeInterval?
    private var wasMouseDown = false
    public init() {}
    public mutating func update(inside: Bool, mouseDown: Bool, time: TimeInterval,
                                kind: GuideInteractionKind, dwellMilliseconds: Int) -> Bool {
        defer { wasMouseDown = mouseDown }
        guard inside else { enteredAt = nil; return false }
        if kind == .click { return mouseDown && !wasMouseDown }
        if enteredAt == nil { enteredAt = time }
        return time - (enteredAt ?? time) >= Double(dwellMilliseconds) / 1000
    }
}
