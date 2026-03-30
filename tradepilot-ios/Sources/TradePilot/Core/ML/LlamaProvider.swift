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
    /// Serializes all model access: load, inference, and unload (fix #25, #27).
    private let modelLock = NSLock()

    /// Path to the GGUF model file in the app's Documents directory.
    let modelPath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(ModelDownloadManager.fileName)
    }()

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    init(engine: LlamaEngine? = nil) {
        self.engine = engine ?? MockLlamaEngine()
    }

    func analyze(prompt: String) async throws -> String {
        guard isAvailable else { throw LLMProviderError.modelNotLoaded }

        // Serialize load + inference under one lock so concurrent calls cannot
        // interleave load/infer/unload operations (fix #25).
        return try await Task.detached(priority: .userInitiated) { [self] in
            modelLock.lock()
            defer { modelLock.unlock() }
            if !isModelLoaded {
                try engine.loadModel(at: modelPath)
                isModelLoaded = true
            }
            do {
                return try engine.infer(prompt: prompt)
            } catch {
                throw LLMProviderError.inferenceFailure(error.localizedDescription)
            }
        }.value
    }

    deinit {
        // Lock prevents unloadModel() racing with an in-flight analyze() (fix #27).
        modelLock.lock()
        defer { modelLock.unlock() }
        if isModelLoaded {
            engine.unloadModel()
        }
    }
}
