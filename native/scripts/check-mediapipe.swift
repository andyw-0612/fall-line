import Foundation
import CoreVideo
import CoreGraphics
import ImageIO

// Compile with MediaPipeHandEngine.swift and CMediaPipe (see check-mediapipe.sh).
@main struct CheckMediaPipe {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 4 else { fatalError("Usage: check-mediapipe runtime model image [image…]") }
        let engine = try MediaPipeHandEngine(library: URL(filePath: args[1]), model: URL(filePath: args[2]))
        var time = 0.0
        for path in args.dropFirst(3) {
            guard let source = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Invalid image: \(path)") }
            var optional: CVPixelBuffer?
            let attributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
            guard CVPixelBufferCreate(nil, image.width, image.height, kCVPixelFormatType_32BGRA, attributes, &optional) == kCVReturnSuccess,
                  let buffer = optional else { fatalError("Pixel buffer allocation failed") }
            CVPixelBufferLockBaseAddress(buffer, [])
            guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else { fatalError("Image conversion failed") }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            let start = ProcessInfo.processInfo.systemUptime
            // Repeated timestamps intentionally exercise the C bridge's monotonic adjustment.
            let landmarks = try engine.detectLandmarks(buffer, at: time)
            let tip = try engine.detect(buffer, at: time)
            precondition(landmarks.isEmpty || landmarks.count == 21, "Google hand output must contain all 21 landmarks")
            if tip != nil { precondition(landmarks.count == 21, "Index tracking must also expose its full skeleton") }
            time += 100
            let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000 / 2
            print("\(URL(filePath: path).lastPathComponent): \(tip.map { "index=(\($0.x), \($0.y))" } ?? "no hand") · \(elapsed.formatted(.number.precision(.fractionLength(1)))) ms/frame · \(landmarks.count) landmarks")
            if path.contains("blank") { precondition(tip == nil, "Blank frame must not acquire a hand") }
            if path.contains("hand-sample") { precondition(tip != nil, "Full-hand smoke fixture must acquire index fingertip") }
        }
    }
}
