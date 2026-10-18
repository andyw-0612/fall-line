import Testing
@testable import MarkingCore

struct RepeatNotchTests {
    private func points(_ legs: [(Direction, Double)], samples: Int = 1, drift: Double = 0) -> [Point] {
        var result = [Point(400,400)], start = result[0]
        for (direction, length) in legs {
            for i in 1...samples {
                let along = direction.sign * length * Double(i) / Double(samples)
                let across = i == samples ? 0 : (i.isMultiple(of: 2) ? -drift : drift)
                result.append(direction.horizontal ? Point(start.x + along, start.y + across) : Point(start.x + across, start.y + along))
            }
            start = result[result.count - 1]
        }
        return result
    }
    private func finish(_ points: [Point]) -> [String]? {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true, canEnter: { _,_,_ in false })
        gesture.start(points[0],at: 0)
        for (i,point) in points.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1) * 3) }
        return gesture.finish()?.map(\.name)
    }
    @Test func tripleRepeatsWorkInEveryDirectionAtDifferentScalesAndSamplingRates() {
        let names: [Direction: [String]] = [
            .up: ["Food","Fruit","Apple"], .right: ["Tools","Fastening","Wrench"],
            .down: ["Animals","Pets","Dog"], .left: ["Vehicles","Air","Helicopter"]
        ]
        for direction in Direction.allCases {
            for length in [10.0,20,50,100,400] {
                for samples in [1,4,16] {
                    let notch = max(3, length * 0.1)
                    let path = points([(direction,length),(direction.opposite,notch),(direction,length),
                                       (direction.opposite,notch),(direction,length)],samples: samples,drift: min(0.3,notch * 0.02))
                    #expect(StrokeRecognizer.segments(path).map(\.direction) == [direction,direction,direction])
                    #expect(finish(path) == names[direction])
                }
            }
        }
    }
    @Test func repeatedDirectionsCanPrecedeOrFollowAnOrdinaryTurn() {
        #expect(finish(points([(.right,100),(.left,8),(.right,100),(.up,100)])) == ["Tools","Fastening","Hammer"])
        #expect(finish(points([(.right,100),(.up,100),(.down,8),(.up,100)])) == ["Tools","Cutting","Saw"])
        #expect(finish(points([(.up,100),(.down,8),(.up,100),(.right,100)])) == ["Food","Fruit","Pear"])
    }
    @Test func notchSizesAreRelativeButAlwaysAboveTheNoiseFloor() {
        for backward in [3.0,5,10,25,34] {
            #expect(finish(points([(.right,100),(.left,backward),(.right,100),(.up,100)])) == ["Tools","Fastening","Hammer"])
        }
        for backward in [0.5,1,2,2.9] {
            let path = points([(.right,100),(.left,backward),(.right,100)])
            #expect(StrokeRecognizer.testVertices(path)?.count == 2)
            #expect(finish(path) == nil)
        }
    }
    @Test func reverseTravelNeverGoesBackAndForwardTravelRearmsWithoutARatioLimit() {
        let backwards = points([(.right,100),(.left,80)])
        #expect(StrokeRecognizer.testVertices(backwards)?.map(\.node.name) == ["Explore","Tools"])
        let partial = points([(.right,100),(.left,80),(.right,100)])
        #expect(StrokeRecognizer.testVertices(partial)?.map(\.node.name) == ["Explore","Tools","Fastening"])
        let path = points([(.right,100),(.left,80),(.right,100),(.up,100),(.right,100)])
        #expect(finish(path) == ["Tools","Fastening","Hammer"])
    }
    @Test func unfinishedNotchDoesNotAddAChoiceAndFinalNotchDoesNotUndo() {
        #expect(finish(points([(.right,100),(.left,8)])) == nil)
        #expect(finish(points([(.right,100),(.left,8),(.right,100),(.left,8)])) == nil)
        #expect(finish(points([(.right,100),(.left,8),(.right,100),(.left,8),(.right,100),(.left,8)])) == ["Tools","Fastening","Wrench"])
    }
    @Test func shortConfirmedForwardTravelCountsWithoutRetracingThePeak() {
        #expect(finish(points([(.right,100),(.left,10),(.right,4),(.up,100)])) == ["Tools","Fastening","Hammer"])
        #expect(finish(points([(.right,100),(.left,10),(.right,2),(.up,100)])) == nil)
    }
    @Test func rapidZigzagsCanEndWithShortForwardStrokesInEveryDirection() {
        let names: [Direction: [String]] = [
            .up: ["Food","Fruit","Apple"], .right: ["Tools","Fastening","Wrench"],
            .down: ["Animals","Pets","Dog"], .left: ["Vehicles","Air","Helicopter"]
        ]
        for direction in Direction.allCases {
            for samples in [1,4,16] {
                for lastLength in [3.0,4,6,8,12] {
                    let path = points([(direction,100),(direction.opposite,8),(direction,8),
                                       (direction.opposite,8),(direction,lastLength)],samples: samples)
                    #expect(finish(path) == names[direction])
                }
            }
        }
    }
    @Test func mouseUpEndpointCompletesTheLastRepeatWithoutAnExtraMoveOrDwell() {
        let path = points([(.right,100),(.left,8),(.right,8),(.left,8),(.right,3)])
        let gesture = MarkingGesture(root: .testRoot, adaptive: true,canEnter: { _,_,_ in false })
        gesture.start(path[0],at: 0)
        for (i,point) in path.dropFirst().dropLast().enumerated() { gesture.move(point,at: Double(i + 1)) }
        // AppModel.end feeds mouseUp's position before finishing; no final drag event exists.
        gesture.move(path[path.count - 1],at: 4.001)
        gesture.advance(at: 4.001)
        #expect(gesture.finish()?.map(\.name) == ["Tools","Fastening","Wrench"])
    }
    @Test func releaseImmediatelyAndAfterHoldingProduceTheSameSelection() {
        let path = points([(.right,100),(.left,8),(.right,8),(.left,8),(.right,4)])
        for release in [5.001,10,100,400,1000] {
            let gesture = MarkingGesture(root: .testRoot, adaptive: true,canEnter: { _,_,_ in false })
            gesture.start(path[0],at: 0)
            for (i,point) in path.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1)) }
            gesture.move(path[path.count - 1],at: release); gesture.advance(at: release)
            #expect(gesture.finish()?.map(\.name) == ["Tools","Fastening","Wrench"])
        }
    }
    @Test func compactRepeatChainsStillIgnoreAnUnfinishedFinalReturn() {
        #expect(finish(points([(.right,100),(.left,8),(.right,3),(.left,8)])) == nil)
        #expect(finish(points([(.right,100),(.left,8),(.right,3),(.left,8),(.right,3),(.left,8)])) == ["Tools","Fastening","Wrench"])
    }
    @Test func shortFinalRepeatSurvivesLongEarlierLegsAndARealCorner() {
        #expect(finish(points([(.up,400),(.right,100),(.left,8),(.right,3)])) == ["Food","Bakery","Croissant"])
        #expect(finish(points([(.right,100),(.left,8),(.right,3),(.up,400)])) == ["Tools","Fastening","Hammer"])
    }
    @Test func belowNoiseFinalPushAndOnlyTwoChoicesDoNotBecomeAThird() {
        for lastLength in [0.0,0.5,1,2,2.9] {
            #expect(finish(points([(.right,100),(.left,8),(.right,8),(.left,8),(.right,lastLength)])) == nil)
        }
        #expect(finish(points([(.right,100),(.left,8),(.right,3)])) == nil)
    }
    @Test func pauseAfterRepeatsRevealsTheCorrectLevelAndSlowBackIsUnchanged() {
        let path = points([(.right,100),(.left,8),(.right,100)])
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        gesture.start(path[0],at: 0)
        for (i,point) in path.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1) * 10) }
        gesture.advance(at: 364)
        #expect(gesture.mode == .slow)
        #expect(gesture.path.map(\.name) == ["Tools","Fastening"])
        let last = path[path.count - 1]
        gesture.move(Point(last.x - 8,last.y),at: 380)
        gesture.advance(at: 520)
        #expect(gesture.path.map(\.name) == ["Tools"])
        #expect(gesture.finish() == nil)
    }
}
