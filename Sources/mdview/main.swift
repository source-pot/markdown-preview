import AppKit
import SwiftUI

// Check if we're running as the detached child process
let isDetached = ProcessInfo.processInfo.environment["MDVIEW_DETACHED"] == "1"

if !isDetached {
    // Parse command line arguments and validate file exists before detaching
    var filePath: String? = nil

    if CommandLine.arguments.count > 1 {
        let path = CommandLine.arguments[1]
        let url = URL(fileURLWithPath: path).standardizedFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            filePath = url.path
        } else {
            fputs("Error: File not found: \(path)\n", stderr)
            exit(1)
        }
    }

    // Re-launch ourselves detached from the terminal
    let process = Process()

    // Get the actual executable path (not just the command name)
    guard let executableURL = Bundle.main.executableURL else {
        fputs("Error: Could not determine executable path\n", stderr)
        exit(1)
    }
    process.executableURL = executableURL

    if let path = filePath {
        process.arguments = [path]
    }

    var env = ProcessInfo.processInfo.environment
    env["MDVIEW_DETACHED"] = "1"
    process.environment = env

    // Detach from terminal by setting standard I/O to null
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        exit(0)
    } catch {
        fputs("Error: Failed to launch app: \(error)\n", stderr)
        exit(1)
    }
}

// Detached child process continues here...

// Parse command line arguments
var initialFilePath: String? = nil

if CommandLine.arguments.count > 1 {
    let path = CommandLine.arguments[1]
    let url = URL(fileURLWithPath: path).standardizedFileURL
    initialFilePath = url.path
}

// Store the initial file path for the app to use
if let path = initialFilePath {
    UserDefaults.standard.set(path, forKey: "initialFilePath")
} else {
    UserDefaults.standard.removeObject(forKey: "initialFilePath")
}

// Launch the app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
