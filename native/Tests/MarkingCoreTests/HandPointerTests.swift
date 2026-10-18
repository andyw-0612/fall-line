import Testing
@testable import MarkingCore

struct HandPointerTests {
    @Test func correctedFingerCoordinatesSelectTheRightHandMenuBranch() {
        for deskView in [true, false] {
            let gesture = MarkingGesture(adaptive: true)
            let samples = [Point(0.5, 0.5), Point(0.5, 0.4), Point(deskView ? 0.6 : 0.4, 0.4)]
            let points = samples.map { HandPose.map($0, width: 1000, height: 800, deskView: deskView) }
            gesture.start(points[0], at: 0)
            gesture.move(points[1], at: 10); gesture.move(points[2], at: 20)
            // Up, then physical right: Price → I Like It, not its left-hand submenu.
            #expect(gesture.finish()?.map(\.name) == ["Price", "I Like It"])
        }
    }
    @Test func deskViewReversesHorizontalMappingWhileNormalCameraStaysUnchanged() {
        for deskView in [true, false] {
            let center = HandPose.map(Point(0.5, 0.5), width: 1000, height: 800, deskView: deskView)
            let higherX = HandPose.map(Point(0.6, 0.5), width: 1000, height: 800, deskView: deskView).x
            let lowerX = HandPose.map(Point(0.4, 0.5), width: 1000, height: 800, deskView: deskView).x
            #expect(deskView ? higherX > center.x : higherX < center.x)
            #expect(deskView ? lowerX < center.x : lowerX > center.x)
            #expect(HandPose.map(Point(0.5, 0.4), width: 1000, height: 800, deskView: deskView).y < center.y)
        }
        #expect(HandPose.interactionPoint(Point(0.2, 0.6), deskView: false) == Point(0.8, 0.6))
        #expect(HandPose.interactionPoint(Point(0.2, 0.6), deskView: true) == Point(0.2, 0.6))
        #expect(HandPose.map(Point(0.2, 0.6), width: 1000, height: 800, deskView: true) == Point(200, 480))
    }

    @Test func holdsTheExactLastPositionFor450MillisecondsWithoutExtendingTheDeadline() {
        var pointer = HandPointerStabilizer()
        let point = Point(0.4, 0.6)
        #expect(pointer.update(nil, at: 0) == .lost)
        #expect(pointer.update(point, at: 10) == .tracked(point))
        for time in [26.0, 100, 300, 460] { #expect(pointer.update(nil, at: time) == .held(point)) }
        #expect(pointer.update(nil, at: 461) == .lost)
        #expect(pointer.update(nil, at: 462) == .lost)
        #expect(pointer.update(Point(0.8, 0.2), at: 500) == .tracked(Point(0.8, 0.2)))
    }

    @Test func invalidCoordinatesCannotMoveTheCursorAndResetClearsTheHold() {
        var pointer = HandPointerStabilizer()
        _ = pointer.update(Point(0.5, 0.5), at: 0)
        #expect(pointer.update(Point(.nan, 0), at: 20) == .held(Point(0.5, 0.5)))
        #expect(pointer.update(Point(1.1, 0), at: 40) == .held(Point(0.5, 0.5)))
        pointer.reset()
        #expect(pointer.update(nil, at: 50) == .lost)
    }

    @Test func strongerSmoothingReducesNoiseButKeepsIntentionalMovementResponsive() {
        var pointer = HandPointerStabilizer()
        var oldFilter = OneEuroFilter()
        _ = pointer.update(Point(0.5, 0.5), at: 0); _ = oldFilter.filter(500, at: 0)
        var newTravel = 0.0, oldTravel = 0.0, previousNew = 500.0, previousOld = 500.0
        for i in 1...90 {
            let raw = 500.0 + (i.isMultiple(of: 2) ? -4.0 : 4.0)
            let sample = pointer.update(Point(raw / 1000, 0.5), at: Double(i) * 16)
            let current = (sample.point?.x ?? 0) * 1000
            let old = oldFilter.filter(raw, at: Double(i) * 16)
            newTravel += abs(current - previousNew); oldTravel += abs(old - previousOld)
            previousNew = current; previousOld = old
        }
        #expect(newTravel < oldTravel * 0.5)
        pointer.reset(); _ = pointer.update(Point(0.5, 0.5), at: 0)
        var current = 0.5
        for i in 1...6 { current = pointer.update(Point(0.7, 0.5), at: Double(i) * 16).point?.x ?? 0 }
        #expect(current > 0.68)
        #expect(current <= 0.7)
    }

    @Test func briefGapsResumeSmoothlyAndLongGapsAcquireWithoutOldFilterLag() {
        var pointer = HandPointerStabilizer()
        _ = pointer.update(Point(0.4, 0.5), at: 0)
        #expect(pointer.update(nil, at: 300) == .held(Point(0.4, 0.5)))
        let resumed = pointer.update(Point(0.42, 0.5), at: 400).point?.x ?? 0
        #expect(resumed > 0.4 && resumed < 0.42)
        #expect(pointer.update(Point(0.8, 0.5), at: 900) == .tracked(Point(0.8, 0.5)))
    }

    @Test func holdingTrackingCannotCompleteAFinalDwellOrCancelTheActiveStroke() {
        let clutch = HandClutch(); clutch.mode = .clutch
        _ = clutch.update(Point(200, 200), at: 0, final: false)
        _ = clutch.setSpace(true, at: 1)
        clutch.mode = .dwell
        _ = clutch.update(Point(210, 200), at: 50, final: true)
        for time in [100.0, 200, 300, 400, 440] {
            clutch.pauseTracking(at: time)
            #expect(clutch.down)
            #expect(clutch.point == Point(210, 200))
        }
        let resumed = clutch.update(Point(210, 200), at: 450, final: true)
        #expect(!resumed.contains(.cancel))
        #expect(!resumed.contains(.finish(Point(210, 200), 450)))
        _ = clutch.update(Point(210, 200), at: 600, final: true)
        #expect(clutch.update(Point(210, 200), at: 770, final: true).contains(.finish(Point(210, 200), 770)))
    }

    @Test func aGapCannotArmTheInitialDwellAndSpaceCanStillReleaseExplicitly() {
        let clutch = HandClutch()
        _ = clutch.update(Point(200, 200), at: 0, final: false)
        _ = clutch.update(Point(200, 200), at: 200, final: false)
        clutch.pauseTracking(at: 300)
        #expect(!clutch.update(Point(220, 200), at: 400, final: false).contains(.begin(Point(200, 200), 300)))
        #expect(!clutch.down)
        clutch.mode = .clutch
        _ = clutch.setSpace(true, at: 401)
        clutch.pauseTracking(at: 500)
        #expect(clutch.setSpace(false, at: 510) == [.finish(Point(220, 200), 510)])
    }
}
