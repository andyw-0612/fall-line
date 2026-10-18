import SwiftUI
@preconcurrency import AVFoundation
import MarkingCore

@MainActor @Observable final class CameraController {
    let pipeline = CapturePipeline()
    var choices: [CameraChoice] = []
    var selectedID = "automatic"
    var isRunning = false
    var isBusy = false
    var isDeskView = false
    var sourceName = ""
    var status = ""
    var previewTip: Point?
    var aspect = 4.0 / 3
    var onFrame: (@MainActor (HandFrame) -> Void)?
    var onRawFrame: (@MainActor (HandFrame) -> Void)?
    var onStop: (@MainActor () -> Void)?
    private var generation = 0
    private var observerTasks: [Task<Void, Never>] = []
    private var watchdog: Task<Void, Never>?
    private var lastFrame = 0.0
    private var pendingStop: Task<Void, Never>?
    private var pointer = HandPointerStabilizer()
    init() {
        choices = CapturePipeline.choices()
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observerTasks.append(Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name).map({ _ in true }) {
                    guard let self else { return }; self.refresh()
                    if self.isRunning && !self.choices.contains(where: { $0.id == self.sourceID }) { self.stop(); self.status = "Camera disconnected." }
                }
            })
        }
        observerTasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification).map({ _ in true }) {
                guard let self, self.isRunning else { continue }; self.stop(); self.status = "Camera interrupted. Enable Desk View to retry."
            }
        })
    }
    private var sourceID = ""
    func refresh() { choices = CapturePipeline.choices() }
    private func permitted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
    func start() async {
        generation += 1; let token = generation; isBusy = true; isRunning = false; pointer.reset(); previewTip = nil; onStop?(); status = "Starting camera…"
        await pendingStop?.value
        await pipeline.stop()
        guard token == generation else { return }
        guard await permitted() else { if token == generation { isBusy = false; status = CameraError.permission.localizedDescription }; return }
        guard token == generation else { return }
        refresh()
        guard let device = choices.first(where: { selectedID == "automatic" ? $0.isDeskView : $0.id == selectedID }) else {
            isBusy = false; status = CameraError.unavailable.localizedDescription; return
        }
        do {
            try await pipeline.start(deviceID: device.id) { [weak self] frame in
                Task { @MainActor [weak self] in self?.received(frame, token: token) }
            }
            guard token == generation else { return }
            sourceID = device.id; sourceName = device.name; isDeskView = device.isDeskView
            isRunning = true; isBusy = false; status = "Show your index finger."; lastFrame = AppModel.now
            watchdog?.cancel()
            watchdog = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    guard let self, self.isRunning else { return }
                    let now = AppModel.now
                    if now - self.lastFrame > 150 {
                        self.onRawFrame?(HandFrame(tip: nil, confidence: 0, time: now, aspect: self.aspect, error: "Camera stalled", isSynthetic: true))
                        self.publish(tip: nil, confidence: 0, time: now, error: nil, stalled: true)
                    }
                }
            }
        } catch {
            guard token == generation else { return }
            await pipeline.stop(); isBusy = false; isRunning = false; status = error.localizedDescription
        }
    }
    func setupDeskView() async {
        generation += 1; let token = generation; isBusy = true; status = "Complete Apple's Desk View setup, then return here."
        isRunning = false; pointer.reset(); previewTip = nil; onStop?(); await pendingStop?.value; await pipeline.stop()
        guard token == generation else { return }
        guard await permitted() else { if token == generation { isBusy = false; status = CameraError.permission.localizedDescription }; return }
        do {
            let configuration = AVCaptureDeskViewApplication.LaunchConfiguration(); configuration.requiresSetUpModeCompletion = true
            try await AVCaptureDeskViewApplication().present(launchConfiguration: configuration)
            guard token == generation else { return }
            selectedID = "automatic"; isBusy = false; refresh(); await start()
        } catch { if token == generation { isBusy = false; status = "Desk View setup: \(error.localizedDescription)" } }
    }
    func stop() {
        generation += 1; isBusy = false; isRunning = false; isDeskView = false; sourceName = ""; previewTip = nil
        watchdog?.cancel(); watchdog = nil; pointer.reset(); onStop?(); status = ""
        pendingStop = Task { await pipeline.stop() }
    }
    func shutdown() async { stop(); await pipeline.stop() }
    private func received(_ frame: HandFrame, token: Int) {
        guard token == generation, isRunning else { return }
        onRawFrame?(frame)
        lastFrame = AppModel.now; aspect = frame.aspect
        publish(tip: frame.tip, confidence: frame.confidence, time: frame.time, error: frame.error)
    }
    private func publish(tip: Point?, confidence: Double, time: Double, error: String?, stalled: Bool = false) {
        if error != nil { pointer.reset() }
        let sample = pointer.update(error == nil ? tip : nil, at: time)
        previewTip = sample.point
        let held: Bool
        switch sample {
        case .tracked:
            held = false; status = "Index fingertip tracked"
        case .held:
            held = true; status = "Holding index cursor · briefly lost tracking"
        case .lost:
            held = false
            status = error ?? (stalled ? "Waiting for camera frames…" : "Looking for your index finger · show your palm to acquire tracking")
        }
        onFrame?(HandFrame(tip: sample.point, confidence: confidence, time: time, aspect: aspect, error: error, isHeld: held))
    }
}
