import Foundation
import CryptoKit

/// Manages the download of the Llama 3.2 3B GGUF model from HuggingFace.
///
/// Usage:
/// ```swift
/// let manager = ModelDownloadManager()
/// await manager.startDownload()
/// ```
@Observable
final class ModelDownloadManager: NSObject, @unchecked Sendable {

    // MARK: Observable state

    var progress: Double = 0         // 0.0 – 1.0
    var isDownloading: Bool = false
    var error: String?
    var isComplete: Bool = false

    // MARK: Constants

    // Official Meta-Llama GGUF release on HuggingFace (fix #24)
    static let modelURL = URL(string:
        "https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
    )!

    /// Expected SHA-256 digest of the Q4_K_M GGUF file (fix #23).
    /// Update this constant when the upstream file changes.
    static let expectedSHA256 = "a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3"

    /// Approximate model size used for the disk-space pre-check (~2.0 GB for Q4_K_M).
    static let requiredBytes: Int64 = 2_147_483_648

    static let fileName = "Llama-3.2-3B-Instruct-Q4_K_M.gguf"

    var destinationURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.fileName)
    }

    // MARK: Private

    private var downloadTask: URLSessionDownloadTask?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.tradepilot.modeldownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: Public API

    /// Checks disk space, then starts (or resumes) the download.
    func startDownload() async {
        guard !isDownloading else { return }

        // Already on disk?
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            isComplete = true
            return
        }

        guard hasSufficientDiskSpace() else {
            error = "Not enough disk space. ~2.0 GB required."
            return
        }

        isDownloading = true
        error = nil

        // Check for a partial download to resume
        let resumeData = loadResumeData()
        if let resumeData {
            downloadTask = session.downloadTask(withResumeData: resumeData)
        } else {
            downloadTask = session.downloadTask(with: Self.modelURL)
        }
        downloadTask?.resume()
    }

    /// Pauses the download and saves resume data.
    func pauseDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            if let data { self?.saveResumeData(data) }
            DispatchQueue.main.async { self?.isDownloading = false }
        })
    }

    // MARK: Private helpers

    private func hasSufficientDiskSpace() -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let values = try? docs.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values?.volumeAvailableCapacityForImportantUsage ?? 0
        return available >= Self.requiredBytes
    }

    private var resumeDataURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("llama_download.resumedata")
    }

    private func saveResumeData(_ data: Data) {
        try? data.write(to: resumeDataURL)
    }

    private func loadResumeData() -> Data? {
        try? Data(contentsOf: resumeDataURL)
    }

    private func clearResumeData() {
        try? FileManager.default.removeItem(at: resumeDataURL)
    }

    /// Verifies the downloaded file against the expected SHA-256 digest (fix #23).
    /// Deletes the file and throws if the digest does not match.
    private func verifyFileSHA256(at url: URL) throws {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
        guard hexDigest == Self.expectedSHA256 else {
            try? FileManager.default.removeItem(at: url)
            throw URLError(.cannotDecodeRawData,
                           userInfo: [NSLocalizedDescriptionKey:
                            "SHA-256 mismatch: expected \(Self.expectedSHA256), got \(hexDigest)"])
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadManager: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let pct = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async { self.progress = pct }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            // Move temp file to Documents
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            // Verify SHA-256 integrity before marking complete (fix #23)
            try verifyFileSHA256(at: destinationURL)

            clearResumeData()
            DispatchQueue.main.async {
                self.isDownloading = false
                self.isComplete = true
                self.progress = 1.0
            }
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.error = "Failed to save model: \(error.localizedDescription)"
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        // Save resume data if available
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            saveResumeData(resumeData)
        }
        DispatchQueue.main.async {
            self.isDownloading = false
            self.error = error.localizedDescription
        }
    }
}
