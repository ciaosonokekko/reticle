import Foundation

enum Log {
    private static let fileURL: URL = {
        let path = "/tmp/Reticle.log"
        return URL(fileURLWithPath: path)
    }()

    static func write(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                    return
                }
            }
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
