import Foundation

class Logger {
    static let shared = Logger()
    private let logFileURL: URL
    
    private init() {
        let tempDir = FileManager.default.temporaryDirectory
        logFileURL = tempDir.appendingPathComponent("stackz.log")
        // Clear log on startup
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            try? FileManager.default.removeItem(at: logFileURL)
        }
        log("Logger initialized at \(logFileURL.path)")
    }
    
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] \(message)\n"
        
        print(formatted, terminator: "")
        
        if let data = formatted.data(using: .utf8) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
}

func SZLog(_ message: String) {
    Logger.shared.log(message)
}
