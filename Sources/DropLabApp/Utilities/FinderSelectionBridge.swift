import AppKit
import Foundation

/// Reads selected files from the active macOS Finder window so the user can summon
/// the Radial Orbit with a hotkey (`⌃⌥Space` / Menu Bar) without even dragging.
@MainActor
public enum FinderSelectionBridge {
    public static func selectedFinderFileURLs() -> [URL] {
        let scriptSource = """
        tell application "Finder"
            set theSelection to selection
            set posixPaths to {}
            repeat with anItem in theSelection
                set end of posixPaths to POSIX path of (anItem as alias)
            end repeat
            return posixPaths
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else { return [] }
        var errorDict: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorDict)
        guard errorDict == nil else { return [] }

        var urls: [URL] = []
        let count = descriptor.numberOfItems
        if count > 0 {
            for idx in 1...count {
                if let path = descriptor.atIndex(idx)?.stringValue {
                    let url = URL(fileURLWithPath: path)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                       !isDir.boolValue {
                        urls.append(url)
                    }
                }
            }
        } else if let singlePath = descriptor.stringValue, !singlePath.isEmpty {
            let url = URL(fileURLWithPath: singlePath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
               !isDir.boolValue {
                urls.append(url)
            }
        }
        return urls
    }
}
