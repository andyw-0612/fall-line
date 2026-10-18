import Testing
@testable import MarkingCore

struct SlowRepeatTests {
    private func offset(_ point: Point, _ direction: Direction, _ length: Double) -> Point {
        direction.horizontal ? Point(point.x + direction.sign * length, point.y) : Point(point.x, point.y + direction.sign * length)
    }
    private func gesture() -> MarkingGesture {
        let gesture = MarkingGesture(root: .testRoot)
        gesture.canEnter = { [weak gesture] direction, _, point in
            guard let center = gesture?.current?.point else { return false }
            return (direction.horizontal ? point.x - center.x : point.y - center.y) * direction.sign >= 40
        }
        return gesture
    }

    @Test func repeatPauseStartsAtPhysicalMotionRatherThanDelayedMenuCommit() {
        for direction in Direction.allCases {
            let gesture = gesture()
            var point = Point(500, 500)
            gesture.start(point, at: 0)
            for step in 0..<3 {
                point = offset(point, direction, 80)
                let time = 10.0 + Double(step) * 190
                gesture.move(point, at: time)
                gesture.advance(at: time + 100)
                #expect(gesture.path.count == step + 1)
            }
            #expect(gesture.finish()?.count == 3)
        }
    }

    @Test func smallJitterCannotPreventOrConsumeARepeatPause() {
        for direction in Direction.allCases {
            let gesture = gesture()
            let origin = Point(500, 500), first = offset(origin, direction, 80)
            gesture.start(origin, at: 0)
            gesture.move(first, at: 10); gesture.advance(at: 110)
            for time in stride(from: 126.0, through: 350, by: 16) {
                let jitter = Int(time).isMultiple(of: 3) ? 1.4 : -1.4
                gesture.move(offset(first, direction, jitter), at: time)
                gesture.advance(at: time)
                #expect(gesture.path.count == 1)
            }
            // Resume gradually, so the armed pause has to survive several samples
            // before both direction confidence and option distance are satisfied.
            for step in 1...20 { gesture.move(offset(first, direction, Double(step) * 4), at: 350 + Double(step) * 8) }
            gesture.advance(at: 650)
            #expect(gesture.path.count == 2)
        }
    }

    @Test func aLongStraightDragStillDoesNotCascadeWhileMenusAreOpening() {
        for direction in Direction.allCases {
            let gesture = gesture(), origin = Point(500, 500)
            gesture.start(origin, at: 0)
            for step in 1...60 {
                let time = Double(step) * 16
                gesture.move(offset(origin, direction, Double(step) * 8), at: time)
                gesture.advance(at: time)
            }
            #expect(gesture.path.count == 1)
            #expect(gesture.finish() == nil)
        }
    }

    @Test func motionDuringTheTransitionDelayDoesNotCountAsAPause() {
        let gesture = gesture()
        gesture.start(Point(500, 500), at: 0)
        gesture.move(Point(580, 500), at: 10)
        gesture.move(Point(600, 500), at: 90)
        gesture.advance(at: 110)
        gesture.move(Point(700, 500), at: 200)
        gesture.advance(at: 300)
        #expect(gesture.path.count == 1)
        #expect(gesture.pending == nil)
    }

    @Test func repeatsStillRequireOptionDistanceAndBackKeepsItsDelay() {
        for direction in Direction.allCases {
            let gesture = gesture(), origin = Point(500, 500)
            let first = offset(origin, direction, 80)
            gesture.start(origin, at: 0)
            gesture.move(first, at: 10); gesture.advance(at: 110)
            gesture.move(offset(first, direction, 20), at: 210)
            gesture.advance(at: 400)
            #expect(gesture.path.count == 1)
            #expect(gesture.pending == nil)
            gesture.move(offset(first, direction, 60), at: 410)
            gesture.advance(at: 510)
            #expect(gesture.path.count == 2)
            let backPoint = offset(offset(first, direction, 60), direction.opposite, 80)
            gesture.move(backPoint, at: 530)
            gesture.advance(at: 669)
            #expect(gesture.path.count == 2)
            gesture.advance(at: 670)
            #expect(gesture.path.count == 1)
        }
    }
}
