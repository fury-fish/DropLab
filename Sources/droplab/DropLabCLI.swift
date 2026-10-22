import Foundation
import DropLabCore

@main
struct DropLabCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let subcommand = args.first else {
            printUsage()
            return
        }

        switch subcommand {
        case "convert":
            await runConvert(args: Array(args.dropFirst()))
        case "targets":
            runTargets(args: Array(args.dropFirst()))
        case "-h", "--help", "help":
            printUsage()
        case "-v", "--version", "version":
            print("droplab 0.2.0 (DropLabCore native engine)")
        default:
            fputs("Unknown command: \(subcommand)\n\n", stderr)
            printUsage()
            exit(1)
        }
    }

    private static func runConvert(args: [String]) async {
        var inputPaths: [String] = []
        var toFormatString: String?
        var presetString: String = "default"
        var trimString: String?
        var outputDirString: String?

        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--to", "-t":
                if i + 1 < args.count {
                    toFormatString = args[i + 1].lowercased()
                    i += 2
                } else {
                    fputs("Error: --to requires a format (e.g., wav, caf, m4a, png, jpg, icns)\n", stderr)
                    exit(1)
                }
            case "--preset", "-p":
                if i + 1 < args.count {
                    presetString = args[i + 1].lowercased()
                    i += 2
                } else {
                    fputs("Error: --preset requires a preset name (e.g., lei16, 24bit, trim8s, scale2x)\n", stderr)
                    exit(1)
                }
            case "--trim":
                if i + 1 < args.count {
                    trimString = args[i + 1]
                    i += 2
                } else {
                    fputs("Error: --trim requires start-end in seconds (e.g., 0-8)\n", stderr)
                    exit(1)
                }
            case "--output-dir", "-o":
                if i + 1 < args.count {
                    outputDirString = args[i + 1]
                    i += 2
                } else {
                    fputs("Error: --output-dir requires a directory path\n", stderr)
                    exit(1)
                }
            default:
                inputPaths.append(arg)
                i += 1
            }
        }

        guard !inputPaths.isEmpty else {
            fputs("Error: Please provide at least one input file path.\n", stderr)
            exit(1)
        }
        guard let toStr = toFormatString, let targetFormat = TargetFormat(rawValue: toStr) else {
            let available = TargetFormat.allCases.map(\.rawValue).joined(separator: ", ")
            fputs("Error: Valid --to format required. Supported: \(available)\n", stderr)
            exit(1)
        }

        let preset = ConversionPreset(rawValue: presetString) ?? .standard
        var customTrim: TimeTrimRange?
        if let trimString {
            let parts = trimString.split(separator: "-").compactMap { Double($0) }
            if parts.count == 2 {
                customTrim = TimeTrimRange(startSeconds: parts[0], endSeconds: parts[1])
            }
        }

        let outputDirectory = outputDirString.map { URL(fileURLWithPath: $0) }
        let options = ConversionOptions(
            targetFormat: targetFormat,
            preset: preset,
            customTrimRange: customTrim,
            outputDirectory: outputDirectory
        )

        let urls = inputPaths.map { URL(fileURLWithPath: $0) }
        do {
            let results = try await DropLabEngine.shared.convertBatch(urls: urls, options: options)
            for res in results {
                print("✓ \(res.sourceURL.lastPathComponent) ➔ \(res.outputURL.path) (\(res.elapsedMilliseconds) ms)")
            }
        } catch {
            fputs("✗ \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func runTargets(args: [String]) {
        guard let firstPath = args.first else {
            fputs("Usage: droplab targets <file>\n", stderr)
            exit(1)
        }
        let url = URL(fileURLWithPath: firstPath)
        let category = FileCategory.detect(for: url)
        let slices = DropLabEngine.shared.registry.orbitSlices(for: url)
        print("File: \(url.lastPathComponent) [Category: \(category.displayName)]")
        for slice in slices {
            let presets = slice.subOrbitPresets.map { "\($0.rawValue) (\($0.displayTitle))" }.joined(separator: ", ")
            print("  • \(slice.targetFormat.label) ➔ Sub-Orbit: [\(presets)]")
        }
    }

    private static func printUsage() {
        print("""
        🧪 DropLab CLI — Context-Aware Native File Converter for macOS

        USAGE:
          droplab convert <file...> --to <format> [--preset <preset>] [--trim <start-end>] [--output-dir <dir>]
          droplab targets <file>

        EXAMPLES:
          droplab convert match.mp3 --to wav --preset lei16
          droplab convert magic.wav --to wav --trim 0-8
          droplab convert photo.heic --to png --preset scale2x
          droplab convert icon.png --to icns
          droplab targets match.mp3
        """)
    }
}
