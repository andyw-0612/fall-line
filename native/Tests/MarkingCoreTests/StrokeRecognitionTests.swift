import Testing
@testable import MarkingCore

struct StrokeRecognitionTests {
    private func path(_ directions: [Direction], length: Double = 100, samples: Int = 1, wobble: Double = 0) -> [Point] {
        var points = [Point(400,400)], corner = points[0]
        for direction in directions {
            for i in 1...samples {
                let along = length * Double(i) / Double(samples) * direction.sign
                let across = i == samples ? 0 : (i.isMultiple(of: 2) ? -wobble : wobble)
                points.append(direction.horizontal ? Point(corner.x + along, corner.y + across) : Point(corner.x + across, corner.y + along))
            }
            corner = points[points.count - 1]
        }
        return points
    }
    @Test func allRightAngleShapesAreScaleAndSamplingIndependent() throws {
        for first in Direction.allCases {
            for second in Direction.allCases where first.horizontal != second.horizontal {
                for third in Direction.allCases where second.horizontal != third.horizontal {
                    let directions = [first,second,third]
                    for length in [8.0,20,70,400] {
                        for samples in [1,4,16] {
                            let points = path(directions,length: length,samples: samples,wobble: length * 0.008)
                            #expect(StrokeRecognizer.segments(points).map(\.direction) == directions)
                            let vertices = try #require(StrokeRecognizer.testVertices(points))
                            #expect(vertices.count == 4)
                            #expect(vertices.last?.node.isLeaf == true)
                        }
                    }
                }
            }
        }
    }
    @Test func fastReleaseRecognizesWholeStrokeWithoutOptionBoxCutoffs() {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true, canEnter: { _,_,_ in false })
        let points = path([.right,.up,.right],length: 20)
        gesture.start(points[0],at: 0)
        for (i,point) in points.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1) * 10) }
        #expect(gesture.mode == .fast)
        #expect(gesture.path.isEmpty) // No premature choices from individual deltas.
        #expect(gesture.finish()?.map(\.name) == ["Tools","Cutting","Scissors"])
    }
    @Test func shallowWobblesAndSmallReleaseHookDoNotAddChoices() {
        let points = [Point(0,0),Point(25,1),Point(50,-1),Point(75,1),Point(100,0),
                      Point(101,-25),Point(99,-50),Point(101,-75),Point(100,-100),
                      Point(125,-101),Point(150,-99),Point(175,-101),Point(200,-100),Point(200,-103)]
        #expect(StrokeRecognizer.segments(points).map(\.direction) == [.right,.up,.right])
        #expect(StrokeRecognizer.testVertices(points)?.last?.node.name == "Scissors")
    }
    @Test func continuousMotionDoesNotNeedAVelocityCutoff() {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        let points = path([.up,.left,.up],length: 30,samples: 3)
        gesture.start(points[0],at: 0)
        for (i,point) in points.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1) * 250) }
        #expect(gesture.mode == .fast)
        #expect(gesture.finish()?.map(\.name) == ["Food","Dessert","Cake"])
    }
    @Test func jitterDoesNotEnterFastModeOrResetOpeningDwell() {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        gesture.start(Point(400,400),at: 0)
        for i in 1...30 { gesture.move(Point(400 + (i.isMultiple(of: 2) ? 1 : -1),400),at: Double(i * 10)) }
        #expect(gesture.mode == .probing)
        gesture.advance(at: 334)
        #expect(gesture.mode == .slow)
        #expect(gesture.path.isEmpty)
        #expect(gesture.finish() == nil)
        let tiny = path([.right,.up,.right],length: 2)
        gesture.start(tiny[0],at: 1000)
        for (i,point) in tiny.dropFirst().enumerated() { gesture.move(point,at: 1010 + Double(i) * 10) }
        #expect(gesture.mode == .probing)
        #expect(gesture.finish() == nil)
    }
    @Test func longStraightStrokeNeverInventsRepeatedChoices() {
        for length in [8.0,70,1000] {
            let gesture = MarkingGesture(root: .testRoot, adaptive: true)
            gesture.start(.zero,at: 0); gesture.move(Point(length,0),at: 10)
            #expect(gesture.finish() == nil)
            #expect(gesture.path.map(\.name) == ["Tools"])
        }
    }
    @Test func pauseRevealsReachedLevelDespiteSmallJitterAndCanContinueSlowly() {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        gesture.start(Point(400,400),at: 0)
        gesture.move(Point(500,400),at: 10); gesture.move(Point(500,300),at: 20)
        gesture.move(Point(501,301),at: 300)
        gesture.advance(at: 354)
        #expect(gesture.mode == .slow)
        #expect(gesture.path.map(\.name) == ["Tools","Cutting"])
        #expect(gesture.current?.point == Point(501,301))
        gesture.move(Point(600,301),at: 360); gesture.advance(at: 460)
        #expect(gesture.finish()?.map(\.name) == ["Tools","Cutting","Scissors"])
    }
    @Test func expertReversalsLeaveTheCurrentLevelAndLeafIntact() {
        #expect(StrokeRecognizer.testVertices(path([.right,.up,.down]))?.map(\.node.name) == ["Explore","Tools","Cutting"])
        #expect(StrokeRecognizer.testVertices(path([.right,.up,.right,.left]))?.last?.node.name == "Scissors")
        #expect(StrokeRecognizer.testVertices(path([.right,.up,.down,.left]))?.last?.node.name == "Knife")
    }
    @Test func ignoredExpertBackCannotUndoOrCancelACompletedSelection() {
        for first in Direction.allCases {
            for second in Direction.allCases where first.horizontal != second.horizontal {
                for third in Direction.allCases where second.horizontal != third.horizontal {
                    let expected = StrokeRecognizer.testVertices(path([first,second,third]))?.map(\.node.name)
                    for samples in [1,4,16] {
                        let points = path([first,second,third,third.opposite],samples: samples)
                        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
                        gesture.start(points[0],at: 0)
                        for (i,point) in points.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1)) }
                        #expect(gesture.finish()?.map(\.name) == expected.map { Array($0.dropFirst()) })
                    }
                }
            }
        }
    }
    @Test func pauseAfterIgnoredBackRevealsTheSameLevelThenSlowBackStillWorks() {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        let points = path([.right,.up,.down])
        gesture.start(points[0],at: 0)
        for (i,point) in points.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1) * 10) }
        gesture.advance(at: 364)
        #expect(gesture.mode == .slow)
        #expect(gesture.path.map(\.name) == ["Tools","Cutting"])
        let last = points[points.count - 1]
        gesture.move(Point(last.x,last.y + 100),at: 380); gesture.advance(at: 520)
        #expect(gesture.path.map(\.name) == ["Tools"])
    }
    @Test func incompleteAndCancelledStrokesCannotCommitButCompletedChoicesStayLatched() {
        let incomplete = path([.right,.up])
        #expect(StrokeRecognizer.testVertices(incomplete)?.last?.node.isLeaf == false)
        #expect(StrokeRecognizer.testVertices(path([.right,.up,.right,.down]))?.last?.node.name == "Scissors")
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        let points = path([.right,.up,.right]); gesture.start(points[0],at: 0)
        for (i,point) in points.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1) * 10) }
        gesture.cancel(); #expect(gesture.finish() == nil)
    }
    @Test func pauseAllowsRepeatedDirectionAndKeyboardRemainsExplicit() {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        gesture.start(Point(400,400),at: 0); gesture.move(Point(400,300),at: 10); gesture.advance(at: 344)
        gesture.move(Point(400,200),at: 350); gesture.advance(at: 450)
        gesture.move(Point(500,200),at: 460); gesture.advance(at: 560)
        #expect(gesture.finish()?.map(\.name) == ["Food","Fruit","Pear"])
        gesture.start(.zero,at: 1000)
        gesture.commit(.right,isBack: false,at: 1001,point: .zero)
        gesture.commit(.up,isBack: false,at: 1002,point: .zero)
        gesture.commit(.right,isBack: false,at: 1003,point: .zero)
        #expect(gesture.finish()?.last?.name == "Scissors")
    }
}
