import Foundation

/// Records conversion batches and allows instant Undo (moving generated files to Trash / removing them).
public final class ConversionHistory: @unchecked Sendable {
    public static let shared = ConversionHistory()

    private let lock = NSLock()
    private var batches: [[ConversionResult]] = []

    public init() {}

    public func record(batch: [ConversionResult]) {
        guard !batch.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        batches.insert(batch, at: 0)
        if batches.count > 25 {
            batches.removeLast(batches.count - 25)
        }
    }

    public var recentResults: [ConversionResult] {
        lock.lock()
        defer { lock.unlock() }
        return batches.flatMap { $0 }
    }

    public var canUndo: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !batches.isEmpty
    }

    /// Removes the files created in the most recent batch and returns the removed URLs.
    @discardableResult
    public func undoLastBatch(fileManager: FileManager = .default) -> [URL] {
        lock.lock()
        guard !batches.isEmpty else {
            lock.unlock()
            return []
        }
        let latest = batches.removeFirst()
        lock.unlock()

        var removed: [URL] = []
        for item in latest {
            if fileManager.fileExists(atPath: item.outputURL.path) {
                if (try? fileManager.trashItem(at: item.outputURL, resultingItemURL: nil)) != nil {
                    removed.append(item.outputURL)
                } else if (try? fileManager.removeItem(at: item.outputURL)) != nil {
                    removed.append(item.outputURL)
                }
            }
        }
        return removed
    }
}
