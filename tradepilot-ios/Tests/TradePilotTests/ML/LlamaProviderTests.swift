import XCTest
@testable import TradePilot

final class LlamaProviderTests: XCTestCase {

    // MARK: - Mock engine

    final class SuccessEngine: LlamaEngine, @unchecked Sendable {
        var loadCalled = false
        var unloadCalled = false
        func loadModel(at path: URL) throws { loadCalled = true }
        func infer(prompt: String) throws -> String { "Mock inference result for: \(prompt)" }
        func unloadModel() { unloadCalled = true }
    }

    final class FailingEngine: LlamaEngine, @unchecked Sendable {
        func loadModel(at path: URL) throws {}
        func infer(prompt: String) throws -> String {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        }
        func unloadModel() {}
    }

    final class LoadFailEngine: LlamaEngine, @unchecked Sendable {
        func loadModel(at path: URL) throws {
            throw NSError(domain: "TestError", code: 2, userInfo: [NSLocalizedDescriptionKey: "load failed"])
        }
        func infer(prompt: String) throws -> String { "" }
        func unloadModel() {}
    }

    // MARK: - Tests

    func testIsUnavailableWhenModelFileMissing() {
        let provider = LlamaProvider(engine: MockLlamaEngine())
        // Model file will not exist in test environment
        XCTAssertFalse(provider.isAvailable)
    }

    func testAnalyzeThrowsModelNotLoadedWhenUnavailable() async {
        let provider = LlamaProvider(engine: MockLlamaEngine())
        XCTAssertFalse(provider.isAvailable)

        do {
            _ = try await provider.analyze(prompt: "test")
            XCTFail("Expected LLMProviderError.modelNotLoaded")
        } catch LLMProviderError.modelNotLoaded {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInferenceFailureWrappedProperly() async throws {
        // We need a provider whose isAvailable returns true.
        // Create a subclass that overrides isAvailable to simulate a present model.
        let engine = FailingEngine()
        let provider = TestableLlamaProvider(engine: engine)

        do {
            _ = try await provider.analyze(prompt: "analyze this")
            XCTFail("Expected inferenceFailure")
        } catch LLMProviderError.inferenceFailure(let msg) {
            XCTAssertTrue(msg.contains("boom"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNameIsSet() {
        let provider = LlamaProvider()
        XCTAssertFalse(provider.name.isEmpty)
        XCTAssertTrue(provider.name.lowercased().contains("llama"))
    }

    func testModelPathIsInDocumentsDirectory() {
        let provider = LlamaProvider()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        XCTAssertTrue(provider.modelPath.path.hasPrefix(docs.path))
        XCTAssertTrue(provider.modelPath.lastPathComponent.hasSuffix(".gguf"))
    }
}

// MARK: - Testable subclass

/// Overrides `isAvailable` to return true so we can test inference paths
/// without actually placing a model file on disk.
private final class TestableLlamaProvider: LlamaProvider, @unchecked Sendable {
    private let _engine: LlamaEngine
    init(engine: LlamaEngine) {
        self._engine = engine
        super.init(engine: engine)
    }
    override var isAvailable: Bool { true }
}
