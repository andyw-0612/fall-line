import Testing
import MarkingCore
import AppKit
@testable import MarkingMenu

@MainActor struct InputDebugTests {
    @Test func rawTrackingClearsOnLossWithoutHoldingSkeleton() {
        let debug = InputDebugState()
        let points = (0..<21).map { Point(Double($0) / 21, 0.4) }
        debug.receive(HandFrame(tip: points[8], confidence: 1, time: AppModel.now, aspect: 1, error: nil, landmarks: points))
        #expect(debug.landmarks.count == 21)
        #expect(debug.indexTip == points[8])
        let capture = debug.captureTime
        debug.receive(HandFrame(tip: nil, confidence: 0, time: AppModel.now, aspect: 1, error: "Camera stalled", isSynthetic: true))
        #expect(debug.frames == 1)
        #expect(debug.captureTime == capture)
        #expect(debug.landmarks.isEmpty)
        #expect(debug.indexTip == nil)
        #expect(debug.trackingStatus == "Camera stalled")
    }

    @Test func detectedAndAcceptedTapCountersAreSeparateAndAnchorCancellationIsVisible() {
        let debug = InputDebugState()
        debug.recordTap(timestamp: 1, magnitude: 0.05, accepted: false, result: "No index tracking")
        debug.recordTap(timestamp: 2, magnitude: 0.08, accepted: true, result: "Registered")
        #expect(debug.tapCount == 2)
        #expect(debug.acceptedTapCount == 1)
        #expect(debug.lastTapMagnitude == 0.08)
        debug.finish("Cancelled · tracking lost before anchor")
        #expect(debug.drawingStatus.contains("tracking lost"))
        #expect(debug.events.first?.message == "Cancelled · tracking lost before anchor")
    }

    @Test func completedTrailsAreRetainedUntilNextStrokeAndNeverJoinTwoDrawings() {
        let debug = InputDebugState()
        debug.beginStroke(size: CGSize(width: 1100, height: 760))
        debug.recordPoint(raw: Point(0.5, 0.5), filtered: Point(0.4, 0.5), screen: Point(300, 400))
        debug.recordPoint(raw: Point(0.6, 0.5), filtered: Point(0.5, 0.5), screen: Point(400, 400))
        debug.finish("Selected")
        debug.recordPoint(raw: Point(0.8, 0.5), filtered: nil, screen: Point(900, 400))
        #expect(debug.rawTrail.count == 2)
        #expect(debug.screenTrail.last == Point(400, 400))
        debug.cameraStopped()
        #expect(debug.screenTrail.count == 2)
        debug.beginStroke(size: CGSize(width: 800, height: 600))
        #expect(debug.screenTrail.isEmpty)
        #expect(debug.rawTrail.isEmpty)
        debug.clear()
        #expect(debug.events.isEmpty)
    }

    @Test func cameraOverlayUsesTheSameMirrorAndLetterboxingAsVideo() {
        let rect = CameraDebugGeometry.videoRect(size: CGSize(width: 800, height: 600), aspect: 2)
        #expect(rect == CGRect(x: 0, y: 100, width: 800, height: 400))
        let raw = Point(0.25, 0.75)
        #expect(CameraDebugGeometry.project(raw, into: rect, deskView: true) == CGPoint(x: 200, y: 400))
        #expect(CameraDebugGeometry.project(raw, into: rect, deskView: false) == CGPoint(x: 600, y: 400))
        #expect(Set(CameraDebugGeometry.connections.flatMap { [$0.0, $0.1] }) == Set(0..<21))
    }

    @Test func fingertipAlwaysUsesLandmarkEightAndRejectsOffFramePredictions() {
        var points = [Point](repeating: Point(0.2, 0.3), count: 21)
        points[8] = Point(0.7, 0.8)
        #expect(HandFrame.indexTip(in: points) == Point(0.7, 0.8))
        points[8] = Point(1.1, 0.8)
        #expect(HandFrame.indexTip(in: points) == nil)
        #expect(HandFrame.indexTip(in: []) == nil)
    }
}
