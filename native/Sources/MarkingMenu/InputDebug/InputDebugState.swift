import SwiftUI
import MarkingCore

@MainActor @Observable final class InputDebugState {
    var landmarks: [Point] = []
    var indexTip: Point?
    var captureTime = 0.0
    var frameAge = 0.0
    var frames = 0
    var trackingStatus = "Camera off"
    var sensorStatus = "Sensor off"
    var acceleration = 0.0
    var effectiveThreshold = 0.025
    var peak = 0.0
    var sensorHz = 0.0
    var tapCount = 0
    var acceptedTapCount = 0
    var lastTapTime: Date?
    var lastTapMagnitude = 0.0
    var lastTapResult = "No palm rest taps detected"
    var drawingStatus = "Waiting for a palm rest tap"
    var isDrawing = false
    private var awaitingAnchor = false
    var rawTrail: [Point] = []
    var filteredTrail: [Point] = []
    var screenTrail: [Point] = []
    var screenSize = CGSize(width: 1100, height: 760)
    var events: [InputDebugEvent] = []

    func receive(_ frame: HandFrame) {
        landmarks = frame.error == nil ? frame.landmarks : []
        indexTip = frame.error == nil ? frame.tip : nil
        if !frame.isSynthetic { captureTime = frame.time; frames += 1 }
        frameAge = captureTime > 0 ? max(0, AppModel.now - captureTime) : 0
        trackingStatus = frame.error ?? (landmarks.isEmpty ? "No hand detected" : "1 hand · \(landmarks.count) landmarks")
    }

    func cameraStopped() {
        landmarks = []; indexTip = nil; trackingStatus = "Camera off"
        sensorStatus = "Sensor off"
    }

    func recordTap(timestamp: Double, magnitude: Double, accepted: Bool, result: String) {
        tapCount += 1
        if accepted { acceptedTapCount += 1 }
        let arrivalAge = ProcessInfo.processInfo.systemUptime - timestamp
        lastTapTime = Date().addingTimeInterval(-max(0, arrivalAge))
        lastTapMagnitude = magnitude
        lastTapResult = result
        if accepted { awaitingAnchor = true; drawingStatus = "Tap registered · waiting for post-impact anchor" }
        log("Palm tap #\(tapCount) · \(magnitude.formatted(.number.precision(.fractionLength(3)))) g · \(result)")
    }

    func beginStroke(size: CGSize) {
        rawTrail = []; filteredTrail = []; screenTrail = []
        screenSize = size; awaitingAnchor = false; isDrawing = true; drawingStatus = "Drawing"
        log("Drawing started · post-impact anchor acquired")
    }

    func recordPoint(raw: Point?, filtered: Point?, screen: Point) {
        guard isDrawing else { return }
        append(raw, to: &rawTrail)
        append(filtered, to: &filteredTrail)
        append(screen, to: &screenTrail)
    }

    func freeze() { drawingStatus = "Path locked · confirming in 100 ms"; log(drawingStatus) }

    func finish(_ outcome: String) {
        guard isDrawing || awaitingAnchor else { return }
        awaitingAnchor = false; isDrawing = false; drawingStatus = outcome
        log(outcome)
        // Retain the last stroke for inspection until the next draw or Clear.
    }

    func clear() {
        rawTrail = []; filteredTrail = []; screenTrail = []; events = []
        tapCount = 0; acceptedTapCount = 0; lastTapTime = nil
        lastTapResult = "No palm rest taps detected"; lastTapMagnitude = 0
        if !isDrawing { drawingStatus = "Waiting for a palm rest tap" }
    }

    private func log(_ text: String) {
        events.insert(InputDebugEvent(time: .now, message: text), at: 0)
        if events.count > 60 { events.removeLast(events.count - 60) }
    }

    private func append(_ point: Point?, to points: inout [Point]) {
        guard let point, point.x.isFinite, point.y.isFinite, points.last != point else { return }
        points.append(point)
        if points.count > 2000 { points.removeFirst(points.count - 2000) }
    }
}
