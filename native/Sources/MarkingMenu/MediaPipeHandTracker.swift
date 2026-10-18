@preconcurrency import AVFoundation
import MarkingCore

/// Delegate callbacks and engine lifetime are serialized by the capture frame queue.
final class MediaPipeHandTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let engine: MediaPipeHandEngine
    private let deliver: @Sendable (HandFrame) -> Void
    private let lock = NSLock()
    private let handle: CaptureSessionHandle

    init(handle: CaptureSessionHandle, deliver: @escaping @Sendable (HandFrame) -> Void) throws {
        guard let resources = Bundle.main.resourceURL,
              let model = Bundle.main.url(forResource: "hand_landmarker", withExtension: "task") else {
            throw NSError(domain: "MediaPipe", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "MediaPipe assets missing. Run native/scripts/prepare-mediapipe.sh and rebuild."])
        }
        self.handle = handle
        engine = try MediaPipeHandEngine(library: resources.appending(path: "libmediapipe.dylib"), model: model)
        self.deliver = deliver
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Anchor palm taps to exposure time on the SPU's host monotonic clock.
        // AVFoundation creates this clock when capture starts; do not cache the
        // pre-start nil value during tracker construction.
        guard let clock = handle.session.synchronizationClock else { return }
        let capture = CMSyncConvertTime(CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
                                       from: clock, to: CMClockGetHostTimeClock())
        let time = CMTimeGetSeconds(capture) * 1000
        guard time.isFinite else { return }
        let aspect = Double(CVPixelBufferGetWidth(buffer)) / Double(CVPixelBufferGetHeight(buffer))
        let frame: HandFrame = lock.withLock {
            do {
                let landmarks = try engine.detectLandmarks(buffer, at: time).map { Point($0.x, $0.y) }
                let tip = HandFrame.indexTip(in: landmarks)
                // Hand Landmarker does not expose calibrated index-tip confidence.
                return HandFrame(tip: tip.map { Point($0.x, $0.y) }, confidence: tip == nil ? 0 : 1,
                                 time: time, aspect: aspect, error: nil, landmarks: landmarks)
            } catch {
                return HandFrame(tip: nil, confidence: 0, time: time, aspect: aspect,
                                 error: "MediaPipe: \(error.localizedDescription)")
            }
        }
        deliver(frame)
    }
}
