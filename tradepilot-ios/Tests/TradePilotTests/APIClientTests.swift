import XCTest
@testable import TradePilot

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

private struct SampleResponse: Codable, Equatable {
    let name: String
    let value: Int
}

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeURL() -> URL { URL(string: "https://api.example.com/test")! }

// MARK: - Tests

final class APIClientTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Success

    func testSuccessfulDecode() async throws {
        let expected = SampleResponse(name: "AAPL", value: 42)
        MockURLProtocol.handler = { _ in
            let data = try JSONEncoder().encode(expected)
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, data)
        }
        let client: APIClient = APIClient(session: makeMockSession(), maxRetries: 1)
        let result: SampleResponse = try await client.fetch(url: makeURL())
        XCTAssertEqual(result, expected)
    }

    // MARK: - Auth errors

    func testUnauthorized401ThrowsUnauthorized() async {
        MockURLProtocol.handler = { _ in
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = APIClient(session: makeMockSession(), maxRetries: 3)
        do {
            let _: SampleResponse = try await client.fetch(url: makeURL())
            XCTFail("Expected APIError.unauthorized")
        } catch APIError.unauthorized {
            // correct
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testForbidden403ThrowsUnauthorized() async {
        MockURLProtocol.handler = { _ in
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = APIClient(session: makeMockSession(), maxRetries: 1)
        do {
            let _: SampleResponse = try await client.fetch(url: makeURL())
            XCTFail("Expected APIError.unauthorized")
        } catch APIError.unauthorized {
            // correct
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Rate limiting

    func testRateLimited429ThrowsRateLimited() async {
        MockURLProtocol.handler = { _ in
            let resp = HTTPURLResponse(
                url: makeURL(), statusCode: 429, httpVersion: nil,
                headerFields: ["Retry-After": "60"]
            )!
            return (resp, Data())
        }
        let client = APIClient(session: makeMockSession(), maxRetries: 1)
        do {
            let _: SampleResponse = try await client.fetch(url: makeURL())
            XCTFail("Expected APIError.rateLimited")
        } catch APIError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, 60)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Server errors

    func testServerError500ThrowsServerError() async {
        MockURLProtocol.handler = { _ in
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = APIClient(session: makeMockSession(), maxRetries: 1)
        do {
            let _: SampleResponse = try await client.fetch(url: makeURL())
            XCTFail("Expected APIError.serverError")
        } catch APIError.serverError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Decoding errors

    func testBadJSONThrowsDecodingError() async {
        MockURLProtocol.handler = { _ in
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("not json".utf8))
        }
        let client = APIClient(session: makeMockSession(), maxRetries: 1)
        do {
            let _: SampleResponse = try await client.fetch(url: makeURL())
            XCTFail("Expected APIError.decodingError")
        } catch APIError.decodingError {
            // correct
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Network errors

    func testNetworkFailureThrowsNetworkError() async {
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let client = APIClient(session: makeMockSession(), maxRetries: 1)
        do {
            let _: SampleResponse = try await client.fetch(url: makeURL())
            XCTFail("Expected APIError.networkError")
        } catch APIError.networkError {
            // correct
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Retry behaviour

    func testRetriesOnTransientFailure() async throws {
        var callCount = 0
        let expected  = SampleResponse(name: "retry", value: 1)

        MockURLProtocol.handler = { _ in
            callCount += 1
            if callCount < 3 {
                throw URLError(.timedOut)
            }
            let data = try JSONEncoder().encode(expected)
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, data)
        }

        let client: APIClient = APIClient(session: makeMockSession(), maxRetries: 3)
        let result: SampleResponse = try await client.fetch(url: makeURL())
        XCTAssertEqual(result, expected)
        XCTAssertEqual(callCount, 3)
    }

    func testNoRetryOn401() async {
        var callCount = 0
        MockURLProtocol.handler = { _ in
            callCount += 1
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = APIClient(session: makeMockSession(), maxRetries: 3)
        _ = try? await client.fetch(url: makeURL()) as SampleResponse
        XCTAssertEqual(callCount, 1, "Should not retry on 401")
    }

    // MARK: - Headers

    func testCustomHeadersAreSent() async throws {
        var receivedHeaders: [String: String] = [:]
        MockURLProtocol.handler = { request in
            receivedHeaders = request.allHTTPHeaderFields ?? [:]
            let data = try JSONEncoder().encode(SampleResponse(name: "h", value: 0))
            let resp = HTTPURLResponse(url: makeURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, data)
        }
        let client: APIClient = APIClient(session: makeMockSession(), maxRetries: 1)
        let _: SampleResponse = try await client.fetch(url: makeURL(), headers: ["X-API-Key": "test-key"])
        XCTAssertEqual(receivedHeaders["X-API-Key"], "test-key")
    }
}
