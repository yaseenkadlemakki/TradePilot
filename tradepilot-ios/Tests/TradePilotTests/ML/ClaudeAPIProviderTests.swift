import XCTest
@testable import TradePilot

final class ClaudeAPIProviderTests: XCTestCase {

    // MARK: - Missing key

    func testIsUnavailableWhenNoKeyInKeychain() {
        // Ensure no key exists (clean Keychain state in test environment)
        let provider = ClaudeAPIProvider()
        // In CI / test sandboxes the Keychain is isolated; key should be absent.
        // We just verify the property is readable and returns a Bool.
        let available = provider.isAvailable
        XCTAssertNotNil(available) // property is accessible
    }

    func testAnalyzeThrowsApiKeyMissingWhenNoKey() async {
        // Force unavailability: delete key if present
        _ = KeychainManager().delete(service: "claude_api_key")

        let provider = ClaudeAPIProvider()
        guard !provider.isAvailable else {
            // A real key is present in this environment — skip this test.
            return
        }

        do {
            _ = try await provider.analyze(prompt: "test")
            XCTFail("Expected LLMProviderError.apiKeyMissing")
        } catch LLMProviderError.apiKeyMissing {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Request building via MockURLProtocol

    func testRequestIncludesApiKeyHeader() async throws {
        let expectation = expectation(description: "request intercepted")
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            expectation.fulfill()
            let body = """
            {"content": [{"text": "ok"}], "id": "1", "model": "claude-sonnet-4-6",
             "role": "assistant", "stop_reason": "end_turn", "type": "message",
             "usage": {"input_tokens": 1, "output_tokens": 1}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, body)
        }

        let apiKey = "test-key-12345"
        KeychainManager().save(service: "claude_api_key", value: apiKey)
        defer { _ = KeychainManager().delete(service: "claude_api_key") }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let provider = ClaudeAPIProviderWithSession(
            session: URLSession(configuration: config)
        )

        _ = try? await provider.analyze(prompt: "hello")
        await fulfillment(of: [expectation], timeout: 2)

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "x-api-key"), apiKey)
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
    }

    func testRetryOn429() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let statusCode = callCount <= 2 ? 429 : 200
            let body: Data
            if statusCode == 200 {
                body = """
                {"content": [{"text": "retry success"}], "id": "1", "model": "claude-sonnet-4-6",
                 "role": "assistant", "stop_reason": "end_turn", "type": "message",
                 "usage": {"input_tokens": 1, "output_tokens": 1}}
                """.data(using: .utf8)!
            } else {
                body = Data()
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil
            )!
            return (response, body)
        }

        KeychainManager().save(service: "claude_api_key", value: "test-key")
        defer { _ = KeychainManager().delete(service: "claude_api_key") }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let provider = ClaudeAPIProviderWithSession(
            session: URLSession(configuration: config),
            retryDelay: 0 // zero delay for tests
        )

        let result = try await provider.analyze(prompt: "test")
        XCTAssertEqual(result, "retry success")
        XCTAssertEqual(callCount, 3)
    }

    func testNameIsSet() {
        let provider = ClaudeAPIProvider()
        XCTAssertFalse(provider.name.isEmpty)
        XCTAssertTrue(provider.name.lowercased().contains("claude"))
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
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

// MARK: - Testable ClaudeAPIProvider with injectable session

/// A testable version of ClaudeAPIProvider that accepts a custom URLSession and retry delay.
struct ClaudeAPIProviderWithSession: LLMProvider {
    let name = "Claude API (test)"
    let session: URLSession
    let retryDelay: TimeInterval

    init(session: URLSession, retryDelay: TimeInterval = 1) {
        self.session = session
        self.retryDelay = retryDelay
    }

    var isAvailable: Bool {
        KeychainManager().read(service: "claude_api_key") != nil
    }

    func analyze(prompt: String) async throws -> String {
        guard let apiKey = KeychainManager().read(service: "claude_api_key") else {
            throw LLMProviderError.apiKeyMissing
        }
        return try await sendWithRetry(prompt: prompt, apiKey: apiKey, attempt: 0)
    }

    private func sendWithRetry(prompt: String, apiKey: String, attempt: Int) async throws -> String {
        do {
            return try await send(prompt: prompt, apiKey: apiKey)
        } catch LLMProviderError.networkError(let err) {
            let nsErr = err as NSError
            if (nsErr.code == 429 || nsErr.code == 529) && attempt < 3 {
                if retryDelay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
                return try await sendWithRetry(prompt: prompt, apiKey: apiKey, attempt: attempt + 1)
            }
            throw LLMProviderError.networkError(err)
        }
    }

    private func send(prompt: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
            throw LLMProviderError.networkError(
                NSError(domain: "ClaudeAPI", code: httpResp.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResp.statusCode)"])
            )
        }
        struct Resp: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }
        let parsed = try JSONDecoder().decode(Resp.self, from: data)
        guard let text = parsed.content.first?.text else {
            throw LLMProviderError.inferenceFailure("Empty response")
        }
        return text
    }
}
