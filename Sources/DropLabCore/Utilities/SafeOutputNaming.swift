import Foundation

/// Generates collision-safe output file URLs next to the source file (or in a custom output directory).
public enum SafeOutputNaming {
    public static func makeOutputURL(
        for sourceURL: URL,
        options: ConversionOptions,
        fileManager: FileManager = .default
    ) -> URL {
        let directory = options.outputDirectory ?? sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let targetExt = options.targetFormat.fileExtension

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
