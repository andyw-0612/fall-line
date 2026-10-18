import Testing
import Foundation
@testable import MarkingCore

struct CoreTests {
    struct Trace: Decodable { var name: String; var options: Options; var steps: [Step] }
    struct Options: Decodable { var adaptive: Bool; var cutoff: Double? }
    struct Step: Decodable { var kind: String; var x: Double?; var y: Double?; var t: Double; var expected: Expected }
    struct Expected: Decodable { var active: Bool; var mode: String; var path: [String]; var final: Bool; var pending: Pending?; var vertices: [Vertex]; var result: [String]? }
    struct Pending: Decodable { var direction: String; var isBack: Bool }
    struct Vertex: Decodable { var id: String; var x: Double; var y: Double }
    @Test func testGoldenSlowNativeTracesMatchSwiftEngine() throws {
        let url = try #require(Bundle.module.url(forResource: "gesture-traces", withExtension: "json", subdirectory: "Fixtures"))
        let traces = try JSONDecoder().decode([Trace].self, from: Data(contentsOf: url))
        XCTAssertEqual(traces.count, 67)
        let slowTraces = traces.filter { !$0.options.adaptive }
        XCTAssertEqual(slowTraces.count, 21)
        for trace in slowTraces {
            let g = MarkingGesture(root: .testRoot, adaptive: trace.options.adaptive)
            if let cutoff = trace.options.cutoff, cutoff > 0 {
                g.canEnter = { direction, _, point in
                    guard let current = g.current else { return false }
                    return (direction.horizontal ? point.x - current.point.x : point.y - current.point.y) * direction.sign >= cutoff
                }
            }
            for (index, step) in trace.steps.enumerated() {
                let label = "\(trace.name) step \(index) \(step.kind)"
                var result: [String]?
                switch step.kind {
                case "start": g.start(Point(step.x ?? 0, step.y ?? 0), at: step.t)
                case "move": g.move(Point(step.x ?? 0, step.y ?? 0), at: step.t)
                case "advance": g.advance(at: step.t)
                case "finish": result = g.finish()?.map(\.id)
                default: g.cancel()
                }
                XCTAssertEqual(g.active, step.expected.active, label)
                XCTAssertEqual(g.mode.rawValue, step.expected.mode, label)
                XCTAssertEqual(g.path.map(\.id), step.expected.path, label)
                XCTAssertEqual(g.final, step.expected.final, label)
                XCTAssertEqual(g.pending?.direction.rawValue, step.expected.pending?.direction, label)
                XCTAssertEqual(g.pending?.isBack, step.expected.pending?.isBack, label)
                XCTAssertEqual(result, step.expected.result, label)
                XCTAssertEqual(g.stack.count, step.expected.vertices.count, label)
                for (vertex, expected) in zip(g.stack, step.expected.vertices) {
                    XCTAssertEqual(vertex.node.id, expected.id, label)
                    XCTAssertEqual(vertex.point.x, expected.x, accuracy: 0.000001, label)
                    XCTAssertEqual(vertex.point.y, expected.y, accuracy: 0.000001, label)
                }
            }
            g.canEnter = { _, _, _ in true } // Break fixture-only self capture.
        }
    }
    @Test func testMenuTreeAndClockwiseBack() {
        func check(_ node: MenuNode, incoming: Direction?) {
            guard !node.isLeaf else { return }
            let choices = node.choices(incoming: incoming)
            XCTAssertEqual(choices.count, 4)
            XCTAssertEqual(choices.count(where: \.isBack), incoming == nil ? 0 : 1)
            if let incoming { XCTAssertTrue(choices.first(where: { $0.direction == incoming.opposite })?.isBack == true) }
            for choice in choices { if let child = choice.node { check(child, incoming: choice.direction) } }
        }
        check(.testRoot, incoming: nil)
    }
    @Test func testOneOrthogonalSegmentPerTransitionAndEdgeBounds() {
        let root = MenuNode.testRoot
        let vertices = [GestureVertex(node: root, incoming: nil, point: Point(223,318)),
                        GestureVertex(node: root, incoming: .right, point: Point(487,347)),
                        GestureVertex(node: root, incoming: .down, point: Point(432,699)),
                        GestureVertex(node: root, incoming: .right, point: Point(845,651))]
        let points = MenuGeometry.centers(vertices, width: 1100, height: 900)
        XCTAssertEqual(points, [Point(220,320),Point(490,320),Point(490,700),Point(850,700)])
        for direction in Direction.allCases {
            let rect = MenuGeometry.optionRect(direction: direction, center: Point(5,5), width: 700, height: 480, labelWidth: 150)
            XCTAssertGreaterThanOrEqual(rect.minX, 10); XCTAssertGreaterThanOrEqual(rect.minY, 10)
            XCTAssertLessThanOrEqual(rect.maxX, 690); XCTAssertLessThanOrEqual(rect.maxY, 462)
        }
    }
    @Test func testGeneralDirectionOvershootAndMinimumDistance() {
        let center = Point(500,500)
        let box = MenuGeometry.optionRect(direction: .up, center: center, width: 1100, height: 900, labelWidth: 90)
        XCTAssertFalse(MenuGeometry.reaches(.up, center: center, point: Point(500,480), box: box))
        XCTAssertTrue(MenuGeometry.reaches(.up, center: center, point: Point(450,200), box: box))
        XCTAssertFalse(MenuGeometry.reaches(.up, center: center, point: Point(100,450), box: box))
    }
    @Test func testScribbleUndoOneShotExpiryAndOrder() {
        var undo = ScribbleUndo(); undo.arm(id: 7, at: 0, point: .zero)
        XCTAssertNil(undo.move(Point(30,0), at: 10)); XCTAssertNil(undo.move(.zero, at: 20))
        XCTAssertEqual(undo.move(Point(30,0), at: 30), 7); XCTAssertNil(undo.move(.zero, at: 40))
        undo.arm(id: 8, at: 0, point: .zero)
        for i in 1...3 { XCTAssertNil(undo.move(Point(i % 2 == 0 ? 0 : 30,0), at: 1600 + Double(i))) }
        undo.arm(id: 9, at: 0, point: .zero); undo.clear(); XCTAssertNil(undo.move(Point(100,0), at: 10))
    }
    @Test func testTrackpadHasPhysicalDirectionsAndReleasesExactlyOnce() {
        var pad = TrackpadStroke(); let origin = Point(500,500)
        XCTAssertEqual(pad.update(count: 1, centroid: nil, origin: origin), [])
        XCTAssertEqual(pad.update(count: 2, centroid: Point(0.5,0.5), origin: origin), [.begin(origin)])
        XCTAssertEqual(pad.update(count: 2, centroid: Point(0.6,0.5), origin: origin), [.move(Point(575,500))])
        let up = pad.update(count: 2, centroid: Point(0.6,0.6), origin: origin)
        guard case let .move(point) = up.first else { Issue.record("Expected a move action"); return }
        XCTAssertEqual(point.y, 425, accuracy: 0.000001)
        XCTAssertEqual(pad.update(count: 1, centroid: nil, origin: origin), [.finish(point)])
        XCTAssertEqual(pad.update(count: 2, centroid: Point(0.4,0.4), origin: origin), [])
        XCTAssertEqual(pad.update(count: 0, centroid: nil, origin: origin), [])
    }
    @Test func testThirdFingerCancelsAndRequiresCompleteLift() {
        var pad = TrackpadStroke(); _ = pad.update(count: 2, centroid: Point(0.5,0.5), origin: .zero)
        XCTAssertEqual(pad.update(count: 3, centroid: nil, origin: .zero), [.cancel])
        XCTAssertEqual(pad.update(count: 2, centroid: Point(0.4,0.4), origin: .zero), [])
        _ = pad.update(count: 0, centroid: nil, origin: .zero)
        XCTAssertEqual(pad.update(count: 2, centroid: Point(0.4,0.4), origin: .zero), [.begin(.zero)])
        pad.invalidateUntilLift()
        XCTAssertEqual(pad.update(count: 2, centroid: Point(0.6,0.6), origin: .zero), [])
        _ = pad.update(count: 0, centroid: nil, origin: .zero)
        XCTAssertEqual(pad.update(count: 2, centroid: Point(0.6,0.6), origin: .zero), [.begin(.zero)])
    }
    @Test func testOneEuroFilterDampsJitterWithoutLargeFlickLag() {
        var filter = OneEuroFilter(); _ = filter.filter(200, at: 0)
        for i in 1...90 { XCTAssertLessThan(abs(filter.filter(200 + (i.isMultiple(of: 2) ? -1 : 1), at: Double(i) * 16) - 200), 0.3) }
        filter.reset(); _ = filter.filter(0, at: 0)
        var value = 0.0
        for i in 1...8 { value = filter.filter(Double(i) * 25, at: Double(i) * 16) }
        XCTAssertLessThan(200 - value, 20)
        XCTAssertEqual(filter.filter(800, at: 1000),800)
    }
    @Test func testDwellStartUsesActualMotionTimestamp() {
        let clutch = HandClutch(); let pointing = HandPose(indexExtended: true, pointing: true, pinched: false)
        for time in [0.0,100,200] { _ = clutch.update(Point(200,200), pose: pointing, at: time, final: false) }
        let actions = clutch.update(Point(208,200), pose: pointing, at: 300, final: false)
        XCTAssertTrue(actions.contains(.begin(Point(200,200),200)))
        XCTAssertTrue(clutch.down)
    }
    @Test func testCurlCommitsAtPreviousDrawingPoint() {
        let clutch = HandClutch(); let relaxed = HandPose(indexExtended: false, pointing: false, pinched: false)
        let pointing = HandPose(indexExtended: true, pointing: true, pinched: false)
        _ = clutch.update(Point(200,200), pose: relaxed, at: 0, final: false)
        _ = clutch.update(Point(200,200), pose: pointing, at: 10, final: false)
        _ = clutch.update(Point(230,200), pose: pointing, at: 20, final: true)
        XCTAssertEqual(clutch.update(Point(100,500), pose: relaxed, at: 30, final: true), [.finish(Point(230,200),30)])
    }
    @Test func testLeafDwellCooldownAndButtonFreeUndoMotion() {
        let clutch = HandClutch(); let pointing = HandPose(indexExtended: true, pointing: true, pinched: false)
        _ = clutch.update(.zero, pose: HandPose(indexExtended: false, pointing: false, pinched: false), at: 0, final: false)
        _ = clutch.update(.zero, pose: pointing, at: 10, final: false)
        var actions: [HandClutch.Action] = []
        for time in stride(from: 20.0, through: 340, by: 40) { actions += clutch.update(.zero, pose: pointing, at: time, final: true) }
        XCTAssertTrue(actions.contains(.finish(.zero,340))); clutch.didFinish(committed: true, at: 340)
        XCTAssertEqual(clutch.update(Point(30,0), pose: pointing, at: 360, final: false), [.move(Point(30,0),360,false)])
        XCTAssertFalse(clutch.down)
    }
    @Test func testClutchUsesSpaceOrPinchAndTrackingLossCancels() {
        let clutch = HandClutch(); clutch.mode = .clutch
        let pointing = HandPose(indexExtended: true, pointing: true, pinched: false)
        _ = clutch.update(.zero, pose: pointing, at: 0, final: false)
        XCTAssertEqual(clutch.setSpace(true, at: 1), [.begin(.zero,1)])
        _ = clutch.update(.zero, pose: HandPose(indexExtended: true, pointing: true, pinched: true), at: 10, final: false)
        XCTAssertEqual(clutch.setSpace(false, at: 11), [])
        XCTAssertEqual(clutch.update(.zero, pose: pointing, at: 20, final: true), [.finish(.zero,20)])
        _ = clutch.setSpace(true, at: 30)
        XCTAssertEqual(clutch.cancel(), [.cancel]); XCTAssertFalse(clutch.down)
    }
    @Test func testTableMappingAndDeskViewFullFrame() {
        XCTAssertEqual(HandPose.map(Point(0.2,0.6), width: 1000, height: 800, deskView: true), Point(200,480))
        let point = HandPose.map(Point(0.85,0.25), width: 1000, height: 800, deskView: false)
        XCTAssertEqual(point.x,0,accuracy:0.000001); XCTAssertEqual(point.y,0)
        XCTAssertEqual(HandPose.map(Point(0,1), width: 1000, height: 800, deskView: false),Point(1000,800))
    }
}

private func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(actual == expected, Comment(rawValue: message), sourceLocation: sourceLocation)
}
private func XCTAssertEqual(_ actual: Double, _ expected: Double, accuracy: Double, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(abs(actual - expected) <= accuracy, Comment(rawValue: message), sourceLocation: sourceLocation)
}
private func XCTAssertTrue(_ condition: Bool, sourceLocation: SourceLocation = #_sourceLocation) { #expect(condition, sourceLocation: sourceLocation) }
private func XCTAssertFalse(_ condition: Bool, sourceLocation: SourceLocation = #_sourceLocation) { #expect(!condition, sourceLocation: sourceLocation) }
private func XCTAssertNil<T>(_ value: T?, sourceLocation: SourceLocation = #_sourceLocation) { #expect(value == nil, sourceLocation: sourceLocation) }
private func XCTAssertLessThan<T: Comparable>(_ actual: T, _ expected: T, sourceLocation: SourceLocation = #_sourceLocation) { #expect(actual < expected, sourceLocation: sourceLocation) }
private func XCTAssertGreaterThanOrEqual<T: Comparable>(_ actual: T, _ expected: T, sourceLocation: SourceLocation = #_sourceLocation) { #expect(actual >= expected, sourceLocation: sourceLocation) }
private func XCTAssertLessThanOrEqual<T: Comparable>(_ actual: T, _ expected: T, sourceLocation: SourceLocation = #_sourceLocation) { #expect(actual <= expected, sourceLocation: sourceLocation) }
