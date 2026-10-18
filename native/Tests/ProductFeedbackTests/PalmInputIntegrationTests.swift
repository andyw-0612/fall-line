import AppKit
import Testing
import MarkingCore
@testable import MarkingMenu

@MainActor struct PalmInputIntegrationTests {
    @Test func everyLeafRequiresTheSavedDistanceOnEveryLeg() {
        func visit(_ node: MenuNode, incoming: Direction?, directions: [Direction]) {
            if node.isLeaf {
                var points = [Point(500, 400)]
                for direction in directions {
                    let p = points.last!
                    let endpoint = Point(p.x + (direction.horizontal ? direction.sign * 80 : 0),
                                         p.y + (direction.horizontal ? 0 : direction.sign * 80))
                    // Camera frames extend each leg after its first turn sample.
                    points.append(Point((p.x + endpoint.x) / 2, (p.y + endpoint.y) / 2))
                    points.append(endpoint)
                }
                #expect(PalmPathQualification.path(points, minimumDistance: 70)?.last?.id == node.id)
                #expect(PalmPathQualification.path(points, minimumDistance: 90) == nil)
                #expect(PalmPathQualification.path(Array(points.dropLast()), minimumDistance: 70)?.last?.id != node.id)
                return
            }
            for choice in node.choices(incoming: incoming) where !choice.isBack {
                if let next = choice.node { visit(next, incoming: choice.direction, directions: directions + [choice.direction]) }
            }
        }
        visit(.root, incoming: nil, directions: [])
    }

    @Test func savedCalibrationSurvivesReloadAndClampsInvalidValues() throws {
        let suite = "FallLineTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(InputSettings.load(from: defaults).pointDistance == 70)
        InputSettings(pointDistance: 110, tapThreshold: 0.015, motionGain: 900).save(to: defaults)
        let restored = InputSettings.load(from: defaults)
        #expect(restored.pointDistance == 110)
        #expect(restored.tapThreshold == 0.015)
        #expect(restored.motionGain == 900)
        defaults.set(-1, forKey: "palm.pointDistance")
        #expect(InputSettings.load(from: defaults).pointDistance == 40)
    }

    @Test func productArrowsNavigateOnceAndNeverStartAFeedbackMenu() throws {
        let model = AppModel()
        var next = 0, previous = 0
        model.onNextProduct = { next += 1 }
        model.onPreviousProduct = { previous += 1 }
        let canvas = GestureCanvasView(model: model, style: .product)
        for (code, repeated) in [(UInt16(124), false), (124, true), (123, false)] {
            let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1,
                windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: repeated, keyCode: code))
            canvas.keyDown(with: event)
        }
        #expect(next == 1)
        #expect(previous == 1)
        #expect(!model.gesture.active)
        #expect(model.history.isEmpty)
    }

    @Test func palmAdapterWaitsForPostImpactExposureAndCannotRestartFromMotion() {
        let input = IndexFingerInput()
        input.smoothing = false; input.snapDirections = false
        let origin = CGPoint(x: 500, y: 400)
        _ = input.update(CGPoint(x: 0.3, y: 0.7), aspect: 1, timestamp: 1, origin: origin)
        _ = input.tap(origin: origin, timestamp: 1.01)
        #expect(input.update(CGPoint(x: 0.3, y: 0.6), aspect: 1, timestamp: 1.03, origin: origin).isEmpty)
        #expect(input.update(CGPoint(x: 0.3, y: 0.5), aspect: 1, timestamp: 1.05, origin: origin).first?.kind == .begin)
        let move = input.update(CGPoint(x: 0.4, y: 0.5), aspect: 1, timestamp: 1.07, origin: origin)
        #expect(abs((move.first?.position.x ?? 0) - 570) < 0.001)
        input.freeze()
        #expect(input.update(CGPoint(x: 0.6, y: 0.5), aspect: 1, timestamp: 1.09, origin: origin).isEmpty)
        input.complete()
        #expect(input.update(CGPoint(x: 0.7, y: 0.5), aspect: 1, timestamp: 1.11, origin: origin).isEmpty)
        _ = input.cancel()
        #expect(input.tap(origin: origin, timestamp: 1.12).isEmpty)
        #expect(input.state == .waitingForTap)
    }
    @Test func fullPalmPathFreezesThenCommitsOnceAndCancellationDropsPendingFeedback() async throws {
        for shouldCancel in [false, true] {
            let model = AppModel()
            model.palm.smoothing = false
            model.palm.gain = 700
            let time = AppModel.now
            func frame(_ x: Double, _ y: Double, _ offset: Double) {
                model.processPalmFrame(HandFrame(tip: Point(x, y), confidence: 1,
                    time: time + offset, aspect: 1, error: nil))
            }
            frame(0.5, 0.5, 0)
            _ = model.palm.tap(origin: CGPoint(x: 500, y: 400), timestamp: time / 1000 + 0.001)
            frame(0.5, 0.5, 40)
            #expect(model.gesture.active)
            frame(0.5, 0.16, 60)
            frame(0.16, 0.16, 80)
            #expect(model.palm.isFrozen)
            #expect(model.history.isEmpty)
            // A trailing hook cannot replace the first accepted complete path.
            frame(0.16, 0.8, 100)
            if shouldCancel { model.cancel() }
            for _ in 0..<100 {
                if !model.gesture.active { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            if shouldCancel { try await Task.sleep(for: .milliseconds(140)) }
            #expect(model.history.count == (shouldCancel ? 0 : 1))
            if !shouldCancel { #expect(model.history.last?.path.last?.id == "price-like") }
            #expect(model.palm.state == .waitingForTap)
            #expect(!model.gesture.active)
            model.cancel()
        }
    }

}
