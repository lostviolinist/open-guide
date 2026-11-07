import XCTest
import GuideCore
@testable import OpenGuide

final class ModelProviderTests: XCTestCase {
    private var session: URLSession!
    override func setUp() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ModelResponseStub.self]
        session = URLSession(configuration: configuration)
        ModelResponseStub.status = 200
        ModelResponseStub.response = Data()
        ModelResponseStub.requestCount = 0
    }
    override func tearDown() { session.invalidateAndCancel(); session = nil }

    func testProviderValidatesAndReturnsToolDocument() async throws {
        let input = try JSONSerialization.jsonObject(with: Data(DemoGuide.continuation.utf8))
        ModelResponseStub.response = try JSONSerialization.data(withJSONObject: ["stop_reason": "tool_use", "content": [["type":"tool_use", "name":"show_guide", "input":input]]])
        let result = try await provider().explain(image: Data([1, 2, 3]), question: "Explain", previous: nil, interaction: nil, model: "test-model")
        XCTAssertEqual(result.title, "The loop is complete")
        XCTAssertEqual(ModelResponseStub.requestCount, 1)
    }
    func testInvalidModelGeometryNeverReachesRenderer() async throws {
        let source = DemoGuide.continuation.replacingOccurrences(of: "\"width\":0.76", with: "\"width\":5")
        let input = try JSONSerialization.jsonObject(with: Data(source.utf8))
        ModelResponseStub.response = try JSONSerialization.data(withJSONObject: ["stop_reason":"tool_use", "content":[["type":"tool_use", "name":"show_guide", "input":input]]])
        do {
            _ = try await provider().explain(image: Data(), question: "Explain", previous: nil, interaction: nil, model: "test-model")
            XCTFail("Invalid geometry must be rejected")
        } catch { XCTAssertTrue(error is GuideProtocolError) }
    }
    func testMissingKeyDoesNotSendScreenshot() async {
        let provider = AnthropicGuideProvider(session: session, readAPIKey: { "" })
        do {
            _ = try await provider.explain(image: Data([1]), question: "Explain", previous: nil, interaction: nil, model: "test-model")
            XCTFail("A key is required")
        } catch { XCTAssertEqual(ModelResponseStub.requestCount, 0) }
    }
    func testAuthenticationErrorDoesNotEchoProviderBody() async {
        ModelResponseStub.status = 401
        ModelResponseStub.response = Data("sensitive upstream detail".utf8)
        do {
            _ = try await provider().explain(image: Data(), question: "Explain", previous: nil, interaction: nil, model: "test-model")
            XCTFail("Authentication failure must be surfaced")
        } catch { XCTAssertFalse(error.localizedDescription.contains("sensitive upstream")) }
    }
    func testTruncatedModelResponseRejected() async throws {
        ModelResponseStub.response = Data(#"{"stop_reason":"max_tokens","content":[]}"#.utf8)
        do {
            _ = try await provider().explain(image: Data(), question: "Explain", previous: nil, interaction: nil, model: "test-model")
            XCTFail("A truncated response cannot render")
        } catch { XCTAssertTrue(error.localizedDescription.contains("incomplete")) }
    }
    private func provider() -> AnthropicGuideProvider {
        AnthropicGuideProvider(session: session, readAPIKey: { "unit-test-placeholder" })
    }
}

private final class ModelResponseStub: URLProtocol {
    static var status = 200
    static var response = Data()
    static var requestCount = 0
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.response)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
