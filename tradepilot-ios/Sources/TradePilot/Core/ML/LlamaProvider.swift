import Foundation

// MARK: - Engine protocol

/// Abstracts the actual llama.cpp calls so we can inject a mock in tests.
/// When the SPM dependency `llama.cpp` is wired, replace MockLlamaEngine
/// with LlamaCppEngine (which wraps the real C++ bridge).
protocol LlamaEngine: Sendable {
    func loadModel(at path: URL) throws
    func infer(prompt: String) throws -> String
    func unloadModel()
}

// MARK: - Mock engine (tests / no-model fallback)

/// Used when the model file is absent or in unit tests.
final class MockLlamaEngine: LlamaEngine, @unchecked Sendable {
    func loadModel(at path: URL) throws {}
    func infer(prompt: String) throws -> String {
        "[MockLlamaEngine] Inference not available — model not loaded."
    }
    func unloadModel() {}
}

// MARK: - Real engine stub
//
// TODO: When `llama.cpp` is added as an SPM dependency, replace this stub
// with the real implementation:
//
//   import llama
//
//   final class LlamaCppEngine: LlamaEngine {
//       private var ctx: OpaquePointer?
//       func loadModel(at path: URL) throws { ... }
//       func infer(prompt: String) throws -> String { ... }
//       func unloadModel() { llama_free(ctx) }
//   }

// MARK: - Provider

/// On-device Llama 3.2 provider backed by llama.cpp.
///
/// Drop-in real inference:
/// 1. Add `.package(url: "https://github.com/ggerganov/llama.cpp", from: "b5400")` to Package.swift
/// 2. Replace `MockLlamaEngine` default with a real `LlamaCppEngine`
final class LlamaProvider: LLMProvider, @unchecked Sendable {

    let name = "Llama 3.2 3B (on-device)"

    private let engine: LlamaEngine
    private var isModelLoaded = false
    private let loadLock = NSLock()

    /// Path to the GGUF model file in the app's Documents directory.
    let modelPath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("llama-3.2-3b-instruct-q4_k_m.gguf")
    }()

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    init(engine: LlamaEngine? = nil) {
        self.engine = engine ?? MockLlamaEngine()
    }

    func analyze(prompt: String) async throws -> String {
        guard isAvailable else { throw LLMProviderError.modelNotLoaded }

        try await Task.detached(priority: .userInitiated) { [self] in
            loadLock.lock()
            defer { loadLock.unlock() }
            if !isModelLoaded {
                try engine.loadModel(at: modelPath)
                isModelLoaded = true
            }
        }.value

        return try await Task.detached(priority: .userInitiated) { [self] in
            do {
                return try engine.infer(prompt: prompt)
            } catch {
                throw LLMProviderError.inferenceFailure(error.localizedDescription)
            }
        }.value
    }

    deinit {
        if isModelLoaded {
            engine.unloadModel()
        }
    }
}
