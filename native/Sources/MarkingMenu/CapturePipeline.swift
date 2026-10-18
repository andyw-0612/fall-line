@preconcurrency import AVFoundation

actor CapturePipeline {
    nonisolated let handle = CaptureSessionHandle()
    private var tracker: MediaPipeHandTracker?
    // AVFoundation's sample-buffer delegate API requires a DispatchQueue.
    // MediaPipe stays on this serial queue; UI delivery uses MainActor tasks.
    private let frames = DispatchQueue(label: "app.markingmenu.vision", qos: .userInteractive)
    static func devices() -> [AVCaptureDevice] {
        let discovered = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera], mediaType: .video, position: .unspecified).devices
        var devices = discovered
        for companion in discovered.compactMap(\.companionDeskViewCamera) where !devices.contains(where: { $0.uniqueID == companion.uniqueID }) { devices.append(companion) }
        return devices
    }
    static func choices() -> [CameraChoice] {
        devices().map { CameraChoice(id: $0.uniqueID, name: $0.localizedName, isDeskView: $0.deviceType == .deskViewCamera) }
            .sorted { $0.isDeskView != $1.isDeskView ? $0.isDeskView : $0.name < $1.name }
    }
    func start(deviceID: String, deliver: @escaping @Sendable (HandFrame) -> Void) throws {
        let session = handle.session
        stop()
        guard let device = Self.devices().first(where: { $0.uniqueID == deviceID }) else { throw CameraError.unavailable }
        session.beginConfiguration()
        do {
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }
            if session.canSetSessionPreset(.high) { session.sessionPreset = .high }
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraError.configuration }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput(); output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let tracker = try MediaPipeHandTracker(handle: handle, deliver: deliver); self.tracker = tracker
            output.setSampleBufferDelegate(tracker, queue: frames)
            guard session.canAddOutput(output) else { throw CameraError.configuration }
            session.addOutput(output)
            if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false
            }
            session.commitConfiguration()
        } catch { session.commitConfiguration(); throw error }
        session.startRunning()
        guard session.isRunning else { throw CameraError.configuration }
    }
    func stop() {
        let session = handle.session
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        for output in session.outputs {
            (output as? AVCaptureVideoDataOutput)?.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(output)
        }
        for input in session.inputs { session.removeInput(input) }
        session.commitConfiguration(); tracker = nil
    }
}
