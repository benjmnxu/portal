import AppKit

enum ScreenshotHelper {
    static func captureInteractivePNG() throws -> String? {
        let tmp = "/tmp/gptportal-\(UUID().uuidString).png"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-i", "-r", "-o", tmp] // interactive; retina; no shadow
        try p.run()
        p.waitUntilExit()

        guard FileManager.default.fileExists(atPath: tmp) else { return nil } // Esc canceled
        let data = try Data(contentsOf: URL(fileURLWithPath: tmp))
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        let b64 = data.base64EncodedString()
        return "data:image/png;base64,\(b64)"
    }
}
