import SwiftUI
import MarkingCore

@MainActor @Observable final class AppModel {
    static let shared = AppModel()
    let gesture = MarkingGesture(adaptive: true)
    let camera = CameraController()
    let inputDebug = InputDebugState()
    let clutch = HandClutch()
    let palm = IndexFingerInput()
    let tapSensor = TapSensor()
    var palmRestEnabled = true
    var inputConfigurationOpen = false
    var tapStatus = "Camera off"
    var inputAvailable = true {
        didSet { if !inputAvailable { cancel() }; syncTapSensor() }
    }
    @ObservationIgnored var onNextProduct: (() -> Void)?
    @ObservationIgnored var onPreviousProduct: (() -> Void)?
    private var palmPoints: [Point] = []
    private var palmLastMotion = 0.0
    private var palmMotionAnchor = Point.zero
    private var palmConfirmation: Task<Void, Never>?
    private var frozenPalmPath: [MenuNode]?
    private var settingsObserver: NSObjectProtocol?
    var inputMode: InputMode = .mouse
    var clutchMode: HandClutch.Mode = .dwell
    var history: [HistoryEntry] = []
    @ObservationIgnored var onSelection: ((HistoryEntry) -> Void)?
    @ObservationIgnored var onUndoSelection: ((Int) -> Void)?
    var revision = 0
    var width = 1100.0
    var height = 760.0
    var fingerPoint: Point?
    var message = ""
    var trackpadSensitivity = 0.75
    var previewVisible = true
    var menuPadding = 16.0
    var menuScale = 1.0
    @ObservationIgnored var focusCanvas: (() -> Void)?
    private var source: InputMode?
    private var nextID = 1
    private var undo = ScribbleUndo()
    @ObservationIgnored private var handTrackingHeld = false
    private var animation: Task<Void, Never>?
    private var lastHandTime: Double?
    private var toastTask: Task<Void, Never>?
    private var previousMouseCoalescing: Bool?
    private let gestureTraces = GestureTraceStore()
    private var gestureSamples: [GestureSample] = []
    private var gestureSampleStart = 0.0
    static var now: Double { ProcessInfo.processInfo.systemUptime * 1000 }
    init() {
        gesture.canEnter = { [weak self] direction, _, point in
            guard let self, let center = self.centers.last, let option = self.options.first(where: { $0.direction == direction }) else { return false }
            return MenuGeometry.reaches(direction, center: center, point: point, box: self.optionRect(option, center: center))
        }
        camera.onFrame = { [weak self] frame in self?.receive(frame) }
        palm.configureFilter(cutoff: 1.5, beta: 6)
        camera.onRawFrame = { [weak self] frame in
            self?.inputDebug.receive(frame); self?.receivePalm(frame)
        }
        camera.onStop = { [weak self] in self?.cancel(); self?.tapSensor.stop(); self?.inputDebug.cameraStopped() }
        tapSensor.onTap = { [weak self] time, magnitude in self?.palmTap(at: time, magnitude: magnitude) }
        tapSensor.onStatus = { [weak self] status in self?.tapStatus = status; self?.inputDebug.sensorStatus = status }
        tapSensor.onTelemetry = { [weak self] magnitude, threshold, peak, hz in
            guard let self else { return }
            self.inputDebug.acceleration = magnitude; self.inputDebug.effectiveThreshold = threshold
            self.inputDebug.peak = peak; self.inputDebug.sensorHz = hz
        }
        settingsObserver = NotificationCenter.default.addObserver(forName: .inputSettingsSaved, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyInputSettings() }
        }
        applyInputSettings()
    }
    var centers: [Point] { MenuGeometry.centers(gesture.stack, width: width, height: height) }
    var options: [MenuChoice] {
        guard let current = gesture.current else { return [] }
        if gesture.final, let incoming = current.incoming {
            return [MenuChoice(direction: incoming, node: current.node), MenuChoice(direction: incoming.opposite, node: nil, isBack: true)]
        }
        return current.node.choices(incoming: current.incoming)
    }
    var menuFont: NSFont {
        NSFont(descriptor: MenuStyle.font.fontDescriptor, size: MenuStyle.font.pointSize * menuScale) ?? MenuStyle.font
    }
    func optionRect(_ option: MenuChoice, center: Point) -> CGRect {
        let textWidth = ("\(option.direction.arrow)  \(option.name)" as NSString).size(withAttributes: [.font: menuFont]).width
        return MenuGeometry.optionRect(direction: option.direction, center: center, width: width, height: height, labelWidth: max(200 * menuScale, textWidth + menuPadding * 2 * menuScale), labelHeight: (14 + menuPadding * 2) * menuScale, centerGap: 165 * menuScale)
    }
    func resized(_ size: CGSize) {
        guard size.width != width || size.height != height else { return }
        cancel(); width = size.width; height = size.height; revision += 1
    }
    @discardableResult func begin(_ point: Point, at time: Double, input: InputMode) -> Bool {
        if gesture.active { cancel() }
        if input == .mouse {
            previousMouseCoalescing = NSEvent.isMouseCoalescingEnabled
            NSEvent.isMouseCoalescingEnabled = false
        }
        if input != .finger { clutch.cancel(); fingerPoint = nil }
        gestureSampleStart = time; gestureSamples = [GestureSample(point: point, time: 0)]
        undo.clear(); source = input; gesture.start(point, at: time); revision += 1; startAnimation(); return true
    }
    func move(_ point: Point, at time: Double, down: Bool, input: InputMode) {
        if down, gesture.active, source == input { recordSample(point, at: time); gesture.move(point, at: time); revision += 1 }
        else if !down, !gesture.active, let id = undo.move(point, at: time) {
            onUndoSelection?(id); history.removeAll { $0.id == id }; toast("Last selection undone"); revision += 1
        }
    }
    @discardableResult func end(_ point: Point, at time: Double, input: InputMode) -> Bool {
        guard gesture.active && source == input else { return false }
        recordSample(point, at: time); gesture.move(point, at: time); gesture.advance(at: time)
        let path = frozenPalmPath ?? gesture.finish()
        if frozenPalmPath != nil { gesture.cancel() }
        recordTrace(termination: "release", path: path?.map(\.name))
        inputDebug.finish(path.map { "Selected · " + $0.map(\.name).joined(separator: " → ") } ?? "Ended without a selection")
        source = nil; animation?.cancel(); animation = nil
        palm.complete(); palmConfirmation?.cancel(); palmConfirmation = nil; frozenPalmPath = nil; palmPoints = []; fingerPoint = nil
        restoreMouseCoalescing()
        if let path {
            let entry = HistoryEntry(id: nextID, path: path); nextID += 1; history.append(entry); onSelection?(entry)
            undo.arm(id: entry.id, at: time, point: point); toast("\(path.last?.name ?? "Option") selected · scribble to undo")
        }
        revision += 1; return path != nil
    }
    func cancel() {
        inputDebug.finish("Cancelled · last trail retained")
        if gesture.active { recordTrace(termination: "cancel", path: nil) }
        restoreMouseCoalescing()
        palmConfirmation?.cancel(); palmConfirmation = nil; frozenPalmPath = nil
        _ = palm.cancel(); palmPoints = []
        animation?.cancel(); animation = nil; gesture.cancel(); source = nil; clutch.cancel()
        handTrackingHeld = false; lastHandTime = nil; fingerPoint = nil; revision += 1
    }
    private func restoreMouseCoalescing() {
        guard let previousMouseCoalescing else { return }
        NSEvent.isMouseCoalescingEnabled = previousMouseCoalescing
        self.previousMouseCoalescing = nil
    }
    private func recordSample(_ point: Point, at time: Double) {
        let sample = GestureSample(point: point, time: time - gestureSampleStart)
        if gestureSamples.count < 4096 { gestureSamples.append(sample) }
        else { gestureSamples[gestureSamples.count - 1] = sample }
    }
    private func recordTrace(termination: String, path: [String]?) {
        guard let source, !gestureSamples.isEmpty else { return }
        let trace = GestureTrace(date: .now, input: source.rawValue, releaseMode: gesture.mode.rawValue,
                                 termination: termination, samples: gestureSamples, selectedPath: path)
        gestureSamples = []
        Task { await gestureTraces.record(trace) }
    }
    func escape() { cancel(); undo.clear() }
    func modeChanged() { cancel(); undo.clear(); syncTapSensor(); focusCanvas?() }
    func clutchChanged() { cancel(); clutch.mode = clutchMode }
    func setSpace(_ held: Bool) {
        guard !palmRestEnabled, inputMode == .finger && camera.isRunning else { return }
        apply(clutch.setSpace(held, at: Self.now))
    }
    func choose(_ direction: Direction) {
        let time = Self.now
        if !gesture.active { begin(Point(width / 2, height / 2), at: time - 200, input: .mouse) }
        gesture.advance(at: time)
        guard let center = centers.last else { return }
        let back = gesture.current?.incoming?.opposite == direction
        if !gesture.final || back {
            guard let option = options.first(where: { $0.direction == direction }) else { return }
            let rect = optionRect(option, center: center)
            gesture.commit(direction, isBack: back, at: time, point: Point(rect.midX, rect.midY)); revision += 1
        }
    }
    func confirmKeyboardSelection() {
        guard gesture.active else { return }
        _ = end(gesture.pointer, at: Self.now, input: source ?? .mouse)
    }
    func undoLast() { guard !history.isEmpty else { return }; cancel(); let entry = history.removeLast(); onUndoSelection?(entry.id); undo.clear(); toast("Last selection undone") }
    func toggleCamera() {
        if camera.isRunning || camera.isBusy { camera.stop(); cancel() }
        else { Task { await camera.start(); if camera.isRunning { inputMode = .finger; modeChanged() } } }
    }
    func setupDeskView() {
        Task {
            await camera.setupDeskView()
            if camera.isRunning { inputMode = .finger; NSApp.activate(); modeChanged() }
        }
    }
    func cameraSelectionChanged() { if camera.isRunning { Task { cancel(); await camera.start() } } }
    func receive(_ frame: HandFrame) {
        guard !palmRestEnabled, inputAvailable, inputMode == .finger, camera.isRunning, NSApp.isActive, source == nil || source == .finger else { return }
        guard let tip = frame.tip else { clutch.cancel(); if source == .finger { cancel() }; handTrackingHeld = false; lastHandTime = nil; fingerPoint = nil; revision += 1; return }
        if frame.isHeld {
            handTrackingHeld = true; clutch.pauseTracking(at: frame.time)
            // Preserve the last cursor/menu, without advancing the stroke or dwell timers.
            return
        }
        handTrackingHeld = false
        if let lastHandTime, frame.time - lastHandTime > HandPointerStabilizer.holdDuration { cancel() }
        lastHandTime = frame.time
        let point = HandPose.map(tip, width: width, height: height, deskView: camera.isDeskView)
        fingerPoint = point
        apply(clutch.update(point, at: frame.time, final: gesture.final)); revision += 1
    }
    private func apply(_ actions: [HandClutch.Action]) {
        for action in actions {
            switch action {
            case let .begin(point, time): begin(point, at: time, input: .finger)
            case let .move(point, time, down): move(point, at: time, down: down, input: .finger)
            case let .finish(point, time):
                let committed = end(point, at: time, input: .finger); clutch.didFinish(committed: committed, at: time)
            case .cancel: cancel()
            }
        }
    }
    private func startAnimation() {
        animation?.cancel()
        animation = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.gesture.active else { break }
                if self.palmRestEnabled, self.source == .finger,
                   Self.now - self.palmLastMotion > 3000 { self.cancel(); break }
                if !self.handTrackingHeld, self.gesture.advance(at: Self.now) { self.revision += 1 }
                do { try await Task.sleep(for: .milliseconds(16)) } catch { break }
            }
        }
    }
    private func toast(_ text: String) {
        message = text; toastTask?.cancel()
        toastTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1.8)) } catch { return }
            self?.message = ""
        }
    }
}

extension AppModel {
    func applyInputSettings() {
        cancel()
        let settings = InputSettings.load()
        tapSensor.threshold = settings.tapThreshold
        palm.gain = settings.motionGain
        syncTapSensor()
    }

    func suspendPalmInput() {
        cancel(); tapSensor.stop()
        inputDebug.sensorStatus = "Sensor paused · app/window lost focus"
    }

    func syncTapSensor() {
        if palmRestEnabled, !inputConfigurationOpen, inputAvailable, inputMode == .finger, camera.isRunning,
           NSApp.isActive, NSApp.keyWindow != nil {
            tapSensor.start()
        } else { tapSensor.stop(); inputDebug.sensorStatus = "Sensor paused · enable camera finger input and focus the app" }
    }

    func palmTap(at time: Double, magnitude: Double = 0) {
        let eligible = palmRestEnabled && !inputConfigurationOpen && inputAvailable && inputMode == .finger && camera.isRunning && NSApp.isActive && NSApp.keyWindow != nil && !gesture.active
        let previous = palm.state
        if eligible { _ = palm.tap(origin: CGPoint(x: width / 2, y: height / 2), timestamp: time) }
        let accepted = eligible && previous == .waitingForTap && palm.state == .awaitingAnchor
        inputDebug.recordTap(timestamp: time, magnitude: magnitude, accepted: accepted,
            result: accepted ? "Registered · awaiting anchor" : !eligible ? "Ignored · input paused or already drawing" : "Ignored · no fresh index tracking or already armed")
    }

    func receivePalm(_ frame: HandFrame) {
        guard palmRestEnabled, !inputConfigurationOpen, inputAvailable, inputMode == .finger, camera.isRunning,
              NSApp.isActive, source == nil || source == .finger else { return }
        processPalmFrame(frame)
    }

    /// Accept only fresh, unheld model samples. Kept separate from UI ownership
    /// checks so capture/impact timing and completion can be tested deterministically.
    func processPalmFrame(_ frame: HandFrame) {
        guard frame.error == nil, Self.now - frame.time <= 150 else { cancel(); return }
        // The export expects native bottom-left Y; Google supplies top-left Y.
        palm.mirrored = !camera.isDeskView
        let raw = frame.tip.map { CGPoint(x: $0.x, y: 1 - $0.y) }
        let events = palm.update(raw, aspect: frame.aspect, timestamp: frame.time / 1000,
                                 origin: CGPoint(x: width / 2, y: height / 2))
        for event in events {
            let point = Point(event.position.x, event.position.y)
            switch event.kind {
            case .begin:
                begin(point, at: frame.time, input: .finger)
                palmPoints = [point]; palmMotionAnchor = point; palmLastMotion = frame.time
                inputDebug.beginStroke(size: CGSize(width: width, height: height))
                recordPalmDebugPoint(frame: frame, point: point)
            case .move:
                if point.distance(to: palmMotionAnchor) >= 8 {
                    palmMotionAnchor = point; palmLastMotion = frame.time
                }
                if palmPoints.last != point { palmPoints.append(point) }
                move(point, at: frame.time, down: true, input: .finger)
                recordPalmDebugPoint(frame: frame, point: point)
                qualifyPalmPath(at: frame.time)
            case .end:
                // A third corner ends at the last accepted point, never commits
                // an incomplete or sub-threshold path.
                if frozenPalmPath == nil { cancel() }
            case .cancel: cancel()
            }
        }
        if palm.state == .drawing { fingerPoint = Point(palm.lastPosition.x, palm.lastPosition.y) }
        else { fingerPoint = nil }
        revision += 1
    }

    private func recordPalmDebugPoint(frame: HandFrame, point: Point) {
        let filtered = palm.preview.map { Point($0.x, 1 - $0.y) }
        inputDebug.recordPoint(raw: frame.tip, filtered: filtered, screen: point)
    }

    private func qualifyPalmPath(at time: Double) {
        guard frozenPalmPath == nil else { return }
        guard let path = PalmPathQualification.path(palmPoints, minimumDistance: InputSettings.load().pointDistance) else { return }
        frozenPalmPath = path
        palm.freeze()
        inputDebug.freeze()
        let point = Point(palm.lastPosition.x, palm.lastPosition.y)
        palmConfirmation = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            guard let self, self.gesture.active, self.frozenPalmPath != nil else { return }
            self.end(point, at: Self.now, input: .finger)
        }
    }
}
