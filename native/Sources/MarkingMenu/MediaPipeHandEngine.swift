import Foundation
import CoreVideo
import Accelerate
import CMediaPipe

/// Serial-use MediaPipe VIDEO session. CapturePipeline owns the serial frame queue.
final class MediaPipeHandEngine {
    private let tracker: OpaquePointer
    private var rgba: [UInt8] = []
    private var scaled: [UInt8] = []

    init(library: URL, model: URL) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard let tracker = MMCreateHandTracker(library.path, model.path, &error) else {
            throw Self.failure(error, fallback: "MediaPipe could not start.")
        }
        self.tracker = tracker
    }

    deinit { MMDestroyHandTracker(tracker) }

    func detect(_ buffer: CVPixelBuffer, at time: Double) throws -> (x: Double, y: Double)? {
        let landmarks = try detectLandmarks(buffer, at: time)
        guard landmarks.count == 21 else { return nil }
        let tip = landmarks[8]
        guard (0...1).contains(tip.x), (0...1).contains(tip.y) else { return nil }
        return (tip.x, tip.y)
    }

    func detectLandmarks(_ buffer: CVPixelBuffer, at time: Double) throws -> [(x: Double, y: Double)] {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA else {
            throw Self.failure(nil, fallback: "MediaPipe requires BGRA camera frames.")
        }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return [] }
        let sourceWidth = CVPixelBufferGetWidth(buffer), sourceHeight = CVPixelBufferGetHeight(buffer)
        let scale = min(1, 960.0 / Double(max(sourceWidth, sourceHeight)))
        let width = max(1, Int(Double(sourceWidth) * scale)), height = max(1, Int(Double(sourceHeight) * scale))
        let count = width * height * 4
        if rgba.count != count { rgba = [UInt8](repeating: 0, count: count); scaled = rgba }
        var source = vImage_Buffer(data: base, height: vImagePixelCount(sourceHeight), width: vImagePixelCount(sourceWidth), rowBytes: CVPixelBufferGetBytesPerRow(buffer))
        var xyz = [Float](repeating: 0, count: 63)
        var error: UnsafeMutablePointer<CChar>?
        let result: Int32 = try scaled.withUnsafeMutableBytes { scaledBytes in
            try rgba.withUnsafeMutableBytes { bytes in
                var intermediate = vImage_Buffer(data: scaledBytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                var destination = vImage_Buffer(data: bytes.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
                let resize = vImageScale_ARGB8888(&source, &intermediate, nil, vImage_Flags(kvImageNoFlags))
                let permute = vImagePermuteChannels_ARGB8888(&intermediate, &destination, [2, 1, 0, 3], vImage_Flags(kvImageNoFlags))
                guard resize == kvImageNoError, permute == kvImageNoError else {
                    throw Self.failure(nil, fallback: "MediaPipe camera conversion failed.")
                }
                return MMDetectHandLandmarks(tracker, bytes.bindMemory(to: UInt8.self).baseAddress, Int32(width), Int32(height), Int64(time), &xyz, &error)
            }
        }
        if result < 0 { throw Self.failure(error, fallback: "MediaPipe inference failed.") }
        return result == 21 ? (0..<21).map { (x: Double(xyz[$0 * 3]), y: Double(xyz[$0 * 3 + 1])) } : []
    }

    private static func failure(_ message: UnsafeMutablePointer<CChar>?, fallback: String) -> NSError {
        let description = message.map { String(cString: $0) } ?? fallback
        MMFreeError(message)
        return NSError(domain: "MediaPipe", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
