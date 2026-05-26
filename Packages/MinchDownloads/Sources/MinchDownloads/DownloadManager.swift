import Foundation
import SwiftData
import UserNotifications
import MinchKit
import MinchPersistence

public final class DownloadManager: NSObject, @unchecked Sendable {
    public static let backgroundIdentifier = "app.minch.background-downloads"

    private let container: ModelContainer
    private let destinationRoot: URL
    private let notifier: Notifier
    private let lock = NSLock()
    private var inflight: [Int: Inflight] = [:]
    public var onFinish: (@Sendable (String) -> Void)?
    public var onProgress: (@Sendable (String, Double) -> Void)?
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.backgroundIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    public init(
        container: ModelContainer,
        destinationRoot: URL = DownloadManager.defaultDestinationRoot(),
        notifier: Notifier = Notifier()
    ) {
        self.container = container
        self.destinationRoot = destinationRoot
        self.notifier = notifier
        super.init()
        _ = session
    }

    public static func defaultDestinationRoot() -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        return downloads.appendingPathComponent("Minch", isDirectory: true)
    }

    public func start(
        url: URL,
        fileID: String,
        transferName: String,
        fileName: String
    ) {
        let safeTransfer = sanitize(transferName)
        let safeFile = sanitize(fileName)
        let destination = destinationRoot
            .appendingPathComponent(safeTransfer, isDirectory: true)
            .appendingPathComponent(safeFile)

        let task = session.downloadTask(with: url)
        task.taskDescription = fileID
        lock.lock()
        inflight[task.taskIdentifier] = Inflight(fileID: fileID, destination: destination, displayName: fileName, task: task)
        lock.unlock()
        task.resume()
    }

    /// Cancels the in-progress download for the given file ID, if any. No-op
    /// when the file isn't being downloaded.
    public func cancel(fileID: String) {
        lock.lock()
        let match = inflight.first(where: { $0.value.fileID == fileID })
        if let entry = match { inflight.removeValue(forKey: entry.key) }
        lock.unlock()
        guard let entry = match else { return }
        entry.value.task.cancel()
        onFinish?(fileID)
    }

    private func consume(taskID: Int) -> Inflight? {
        lock.lock()
        defer { lock.unlock() }
        return inflight.removeValue(forKey: taskID)
    }

    private func peek(taskID: Int) -> Inflight? {
        lock.lock()
        defer { lock.unlock() }
        return inflight[taskID]
    }

    private func sanitize(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?\"<>|")
        let cleaned = s.unicodeScalars.map { bad.contains($0) ? "_" : Character($0) }
        let result = String(cleaned)
        return result.isEmpty ? "Untitled" : result
    }

    private struct Inflight {
        let fileID: String
        let destination: URL
        let displayName: String
        let task: URLSessionDownloadTask
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        guard let info = peek(taskID: downloadTask.taskIdentifier) else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress?(info.fileID, progress)
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let info = peek(taskID: downloadTask.taskIdentifier) else { return }
        let fm = FileManager.default
        let parent = info.destination.deletingLastPathComponent()
        try? fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try? fm.removeItem(at: info.destination)
        do {
            try fm.moveItem(at: location, to: info.destination)
        } catch {
            _ = consume(taskID: downloadTask.taskIdentifier)
            onFinish?(info.fileID)
            return
        }
        _ = consume(taskID: downloadTask.taskIdentifier)

        let container = container
        let notifier = notifier
        let destination = info.destination
        let fileID = info.fileID
        let displayName = info.displayName
        let onFinish = onFinish
        Task { @MainActor in
            Self.markDownloaded(container: container, fileID: fileID, path: destination.path)
            await notifier.completed(name: displayName, path: destination.path)
            onFinish?(fileID)
        }
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        guard let info = consume(taskID: task.taskIdentifier) else { return }
        let notifier = notifier
        let displayName = info.displayName
        let fileID = info.fileID
        let message = error.localizedDescription
        let onFinish = onFinish
        Task { @MainActor in
            await notifier.failed(name: displayName, reason: message)
            onFinish?(fileID)
        }
    }

    @MainActor
    private static func markDownloaded(container: ModelContainer, fileID: String, path: String) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<StoredTransferFile>(
            predicate: #Predicate { $0.id == fileID }
        )
        guard let row = try? context.fetch(descriptor).first else { return }
        row.isDownloaded = true
        row.localPath = path
        try? context.save()
    }
}
