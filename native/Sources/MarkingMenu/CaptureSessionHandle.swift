@preconcurrency import AVFoundation

// AVFoundation explicitly supports a preview layer consuming the session while
// capture runs on a worker. All configuration/start/stop mutation is actor-owned.
final class CaptureSessionHandle: @unchecked Sendable {
    let session = AVCaptureSession()
}
