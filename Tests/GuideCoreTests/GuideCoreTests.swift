import CoreGraphics
import XCTest
@testable import GuideCore

final class GuideCoreTests: XCTestCase {
    func testDemoDocumentsValidateAndRoundTrip() throws {
        for source in [DemoGuide.introduction, DemoGuide.continuation] {
            let document = try GuideDocument.decode(Data(source.utf8))
            XCTAssertEqual(document, try GuideDocument.decode(JSONEncoder().encode(document)))
        }
    }
    func testUnsupportedVersionRejected() {
        assertInvalid(DemoGuide.introduction.replacingOccurrences(of: "\"version\":1", with: "\"version\":2"))
    }
    func testOutOfBoundsRectRejected() {
        assertInvalid(DemoGuide.introduction.replacingOccurrences(of: "\"width\":0.84", with: "\"width\":1.5"))
    }
    func testUnknownCommandsRejected() {
        assertInvalid(DemoGuide.introduction.replacingOccurrences(of: "\"kind\":\"arrow\"", with: "\"kind\":\"execute\""))
    }
    func testDuplicateStepIdentifiersRejected() {
        assertInvalid(DemoGuide.introduction.replacingOccurrences(of: "\"id\":\"connect\"", with: "\"id\":\"notice\""))
    }
    func testOversizedDocumentRejected() {
        XCTAssertThrowsError(try GuideDocument.decode(Data(repeating: 32, count: 256_001)))
    }
    func testInvalidDwellRejected() {
        assertInvalid(DemoGuide.introduction.replacingOccurrences(of: "\"dwellMilliseconds\":700", with: "\"dwellMilliseconds\":0"))
    }
    func testWaitMustBeLast() throws {
        let document = try GuideDocument.decode(Data(DemoGuide.introduction.utf8))
        let reversed = GuideDocument(version: 1, title: document.title, steps: document.steps.reversed())
        XCTAssertThrowsError(try reversed.validate())
    }
    func testCoordinateMappingOnOffsetDisplay() {
        let region = CGRect(x: -1440, y: 300, width: 1000, height: 800)
        let rect = GuideRect(x: 0.2, y: 0.25, width: 0.3, height: 0.1).appKitFrame(in: region)
        XCTAssertEqual(rect.minX, -1240, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 820, accuracy: 0.001)
        XCTAssertEqual(rect.width, 300)
        XCTAssertEqual(rect.height, 80)
    }
    func testHoverRequiresContinuousDwell() {
        var gate = InteractionGate()
        XCTAssertFalse(gate.update(inside: true, mouseDown: false, time: 1, kind: .hover, dwellMilliseconds: 700))
        XCTAssertFalse(gate.update(inside: false, mouseDown: false, time: 1.6, kind: .hover, dwellMilliseconds: 700))
        XCTAssertFalse(gate.update(inside: true, mouseDown: false, time: 2, kind: .hover, dwellMilliseconds: 700))
        XCTAssertTrue(gate.update(inside: true, mouseDown: false, time: 2.8, kind: .hover, dwellMilliseconds: 700))
    }
    func testDraggingIntoTargetDoesNotCountAsClick() {
        var gate = InteractionGate()
        XCTAssertFalse(gate.update(inside: false, mouseDown: true, time: 1, kind: .click, dwellMilliseconds: 700))
        XCTAssertFalse(gate.update(inside: true, mouseDown: true, time: 2, kind: .click, dwellMilliseconds: 700))
        XCTAssertFalse(gate.update(inside: true, mouseDown: false, time: 3, kind: .click, dwellMilliseconds: 700))
        XCTAssertTrue(gate.update(inside: true, mouseDown: true, time: 4, kind: .click, dwellMilliseconds: 700))
    }
    private func assertInvalid(_ source: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try GuideDocument.decode(Data(source.utf8)), file: file, line: line)
    }
}
