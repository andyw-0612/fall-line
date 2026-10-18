import Testing
import Foundation
@testable import MarkingCore

struct NaturalFastGestureTests {
    private func selected(_ points: [Point]) -> [String]? {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true, canEnter: { _,_,_ in false })
        gesture.start(points[0],at: 0)
        for (i,point) in points.dropFirst().enumerated() { gesture.move(point,at: Double(i + 1)) }
        return gesture.finish()?.map(\.name)
    }
    @Test func unevenCompactZigzagsDoNotDependOnReverseLengthRatios() {
        #expect(selected([Point(0,0),Point(20,0),Point(8,0),Point(26,0),Point(16,0),Point(30,0)]) == ["Tools","Fastening","Wrench"])
    }
    @Test func diagonalReturnFlicksStillRepeatTheEstablishedDirection() {
        #expect(selected([Point(0,0),Point(50,0),Point(43,-7),Point(51,0),Point(44,7),Point(52,0)]) == ["Tools","Fastening","Wrench"])
    }
    @Test func shortTurnsAreNotDiscardedBecauseTheFirstLegWasLong() {
        #expect(selected([Point(0,0),Point(400,0),Point(400,-8),Point(408,-8)]) == ["Tools","Cutting","Scissors"])
    }
    @Test func extraReleaseMovementCannotCancelACompletedFastChoice() {
        #expect(selected([Point(0,0),Point(100,0),Point(100,-100),Point(200,-100),Point(200,-90)]) == ["Tools","Cutting","Scissors"])
        #expect(selected([Point(0,0),Point(30,0),Point(24,0),Point(32,0),Point(26,0),Point(34,0),Point(28,0),Point(36,0)]) == ["Tools","Fastening","Wrench"])
    }
    @Test func continuousSmallZigzagsDoNotAccidentallyBecomeSlowMode() {
        let gesture = MarkingGesture(root: .testRoot, adaptive: true)
        gesture.start(.zero,at: 0); gesture.move(Point(100,0),at: 10)
        for (i,point) in [Point(97,0),Point(100,0),Point(97,0),Point(100,0)].enumerated() {
            let time = 110 + Double(i) * 100
            gesture.advance(at: time - 1); gesture.move(point,at: time)
        }
        #expect(gesture.mode == .fast)
        #expect(gesture.finish()?.map(\.name) == ["Tools","Fastening","Wrench"])
    }
    @Test func variedAnglesSizesAndSamplingRatesRecognizeTheSameIntent() {
        func expected(_ directions: [Direction]) -> [String] {
            var node = MenuNode.testRoot, incoming: Direction?
            var names: [String] = []
            for direction in directions {
                guard let child = node.choices(incoming: incoming).first(where: { $0.direction == direction })?.node else { return [] }
                node = child; incoming = direction; names.append(child.name)
            }
            return names
        }
        for first in Direction.allCases {
            for turn in Direction.allCases where first.horizontal != turn.horizontal {
                for directions in [[first,first,first],[first,first,turn],[first,turn,turn],[first,turn,first]] {
                    for size in [12.0,40,100,400] {
                        for samples in [1,4,16] {
                            for notchAngle in [-40.0,0,40] {
                                for reverseRatio in [0.15,0.8] {
                                    var points = [Point(400,400)]
                                    func append(_ direction: Direction, length: Double, angle: Double) {
                                        let start = points[points.count - 1]
                                        let radians = angle * .pi / 180
                                        let x = direction.horizontal ? direction.sign * length : 0
                                        let y = direction.horizontal ? 0 : direction.sign * length
                                        let dx = x * cos(radians) - y * sin(radians)
                                        let dy = x * sin(radians) + y * cos(radians)
                                        for i in 1...samples {
                                            let f = Double(i) / Double(samples)
                                            points.append(Point(start.x + dx * f,start.y + dy * f))
                                        }
                                    }
                                    for (i,direction) in directions.enumerated() {
                                        if i > 0 && direction == directions[i - 1] {
                                            append(direction.opposite,length: max(5,size * reverseRatio),angle: notchAngle)
                                        }
                                        let length = i == 0 ? size : max(8,size * (i == 1 ? 0.25 : 0.1))
                                        append(direction,length: length,angle: i.isMultiple(of: 2) ? 15 : -15)
                                    }
                                    #expect(selected(points) == expected(directions))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    @Test func smallJitterOnAStraightStrokeCannotInventChoices() {
        for direction in Direction.allCases {
            var points = [Point(400,400)]
            for i in 1...500 {
                let along = Double(i) * direction.sign
                let across = sin(Double(i) * 1.7) * 1.2
                points.append(direction.horizontal ? Point(400 + along,400 + across) : Point(400 + across,400 + along))
            }
            #expect(StrokeRecognizer.segments(points).count == 1)
            #expect(selected(points) == nil)
        }
    }
    @Test func curvedCornersKeepTheirGeneralDirection() {
        let points = [Point(0,0),Point(80,0),Point(90,-1),Point(97,-4),Point(100,-10),
                      Point(100,-80),Point(101,-90),Point(104,-97),Point(110,-100),Point(180,-100)]
        #expect(selected(points) == ["Tools","Cutting","Scissors"])
    }
}
