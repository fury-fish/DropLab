import Foundation

/// Generates collision-safe output file URLs next to the source file (or in a custom output directory).
public enum SafeOutputNaming {
    public static func makeOutputURL(
        for sourceURL: URL,
        options: ConversionOptions,
        fileManager: FileManager = .default
    ) -> URL {
        let preferredDir = options.outputDirectory ?? sourceURL.deletingLastPathComponent()
        let directory: URL
        if fileManager.isWritableFile(atPath: preferredDir.path) {
            directory = preferredDir
        } else if let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
                  fileManager.isWritableFile(atPath: downloads.path) {
            directory = downloads
        } else {
            directory = URL(fileURLWithPath: NSTemporaryDirectory())
        }
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let targetExt = (options.preset == .appIconSet) ? "appiconset" : options.targetFormat.fileExtension

        var stem = baseName
        if let suffix = options.preset.filenameSuffix {
            stem = "\(baseName)_\(suffix)"
        } else if let trim = options.customTrimRange {
            let s = Int(trim.startSeconds)
            let e = Int(trim.endSeconds)
            stem = "\(baseName)_\(s)s-\(e)s"
        }

        let firstCandidate = directory.appendingPathComponent("\(stem).\(targetExt)")
        if firstCandidate.standardizedFileURL != sourceURL.standardizedFileURL,
           !fileManager.fileExists(atPath: firstCandidate.path) {
            return firstCandidate
        }

        var counter = 2
        while counter < 10_000 {
            let candidate = directory.appendingPathComponent("\(stem) \(counter).\(targetExt)")
            if candidate.standardizedFileURL != sourceURL.standardizedFileURL,
               !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }

        let fallbackUUID = UUID().uuidString.prefix(6)
        return directory.appendingPathComponent("\(stem)_\(fallbackUUID).\(targetExt)")
    }
}
