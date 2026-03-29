import Foundation

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

    static let modelURL = URL(string:
        "https://huggingface.co/TheBloke/Llama-3.2-3B-Instruct-GGUF/resolve/main/llama-3.2-3b-instruct.Q4_K_M.gguf"
    )!

    /// Approximate model size used for the disk-space pre-check (~2.5 GB).
    static let requiredBytes: Int64 = 2_684_354_560

    static let fileName = "llama-3.2-3b-instruct-q4_k_m.gguf"

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
            error = "Not enough disk space. ~2.5 GB required."
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

    /// Verifies the downloaded file has a non-trivial size (integrity check).
    private func verifyFile(at url: URL) -> Bool {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? Int64 ?? 0
        // Require at least 1 GB (sanity check — real model is ~2.5 GB)
        return size >= 1_073_741_824
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

            guard verifyFile(at: destinationURL) else {
                throw URLError(.cannotDecodeRawData)
            }
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
