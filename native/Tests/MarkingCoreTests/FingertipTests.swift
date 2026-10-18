import Testing
import Foundation
@testable import MarkingCore

struct FingertipTests {
    @Test func outputUsesObjectnessBothLabelsAndSuppressesOverlappingBoxes() {
        let rows: [[Double]] = [
            [208,104,42,84,0.9,0.8,0.1],
            [209,105,42,84,0.8,0.8,0.1],
            [104,312,30,40,0.9,0.1,0.9],
            [300,100,30,40,0.3,0.99,0.99],
            [300,100,30,40,0.9,0.1,0.1],
            [.nan,100,30,40,0.9,0.9,0.1]
        ]
        let tips = FingertipDecoder.decode(rows: rows.count) { rows[$0][$1] }
        #expect(tips.count == 2)
        #expect(tips[0].point == Point(0.25,0.75))
        #expect(abs(tips[1].point.x - 0.5) < 0.00001)
        #expect(abs(tips[1].point.y - 0.25) < 0.00001)
        #expect(abs(tips[1].confidence - 0.72) < 0.00001)
    }
    @Test func acquiresAutomaticallyMaintainsIdentityAndReacquiresAfterLoss() {
        func tip(_ x: Double, _ confidence: Double) -> FingertipDetection {
            FingertipDetection(bounds: CGRect(x: x - 0.02, y: 0.48, width: 0.04, height: 0.04), confidence: confidence)
        }
        var tracker = FingertipAssociation()
        #expect(tracker.select([tip(0.2,0.9),tip(0.8,0.8)],at: 0)?.point.x == 0.2)
        #expect(tracker.select([tip(0.22,0.6),tip(0.8,0.99)],at: 16)?.point.x == 0.22)
        #expect(tracker.select([],at: 32) == nil)
        #expect(tracker.select([tip(0.8,0.99)],at: 50) == nil)
        #expect(tracker.select([tip(0.8,0.99)],at: 300)?.point.x == 0.8)
    }
    @Test func fingertipOnlyDwellStartsAndFinishesWithoutHandPose() {
        let clutch = HandClutch()
        for time in [0.0,100,200] { _ = clutch.update(Point(200,200), at: time, final: false) }
        let start = clutch.update(Point(210,200), at: 220, final: false)
        #expect(start.contains(.begin(Point(200,200),200)))
        #expect(clutch.down)
        var actions: [HandClutch.Action] = []
        for time in stride(from: 240.0, through: 560, by: 40) {
            actions += clutch.update(Point(210,200), at: time, final: true)
        }
        #expect(actions.contains(.finish(Point(210,200),560)))
        #expect(!clutch.down)
    }
    @Test func fingertipOnlySpaceAndLossCancelWithoutCommit() {
        let clutch = HandClutch(); clutch.mode = .clutch
        _ = clutch.update(.zero, at: 0, final: false)
        #expect(clutch.setSpace(true, at: 10) == [.begin(.zero,10)])
        #expect(clutch.update(Point(10,0),at: 20,final: false) == [.move(Point(10,0),20,true)])
        #expect(clutch.setSpace(false,at: 30) == [.finish(Point(10,0),30)])
        _ = clutch.setSpace(true,at: 40)
        #expect(clutch.cancel() == [.cancel])
        #expect(!clutch.down)
        #expect(clutch.setSpace(false,at: 50).isEmpty)
    }
}
