import AppKit
import Testing
import MarkingCore
@testable import MarkingMenu

@MainActor struct ProductFeedbackTests {
    @Test func everyFeedbackLeafNamesItsAttributeAndSentiment() {
        var paths: [[MenuNode]] = []
        func collect(_ node: MenuNode, path: [MenuNode]) {
            if node.isLeaf { paths.append(path + [node]) }
            else { for child in node.children { collect(child, path: path + [node]) } }
        }
        for child in MenuNode.root.children { collect(child, path: []) }
        #expect(paths.count == 17)
        for path in paths {
            let message = HistoryEntry(id: 1, path: path).feedbackMessage
            let liked = path.last?.id.hasSuffix("-like") == true
            #expect(message.hasPrefix(liked ? "You liked the " : "You did not like the "))
            #expect(!message.contains("I Like It"))
            #expect(!message.contains("I Don't Like It"))
        }
        let price = try! #require(paths.first { $0.last?.id == "price-too-expensive" })
        #expect(HistoryEntry(id: 1, path: price).feedbackMessage == "You did not like the price (too expensive)")
    }

    @Test func mouseExpertSelectionCanBeScribbledAwayWithoutAButton() {
        let model = AppModel()
        model.menuPadding = 24
        model.menuScale = 0.75
        model.begin(Point(500, 400), at: 1000, input: .mouse)
        model.move(Point(500, 350), at: 1010, down: true, input: .mouse)
        model.move(Point(550, 350), at: 1020, down: true, input: .mouse)
        #expect(model.end(Point(550, 350), at: 1030, input: .mouse))
        #expect(model.history.last?.feedbackMessage == "You liked the price")
        for (index, x) in [580.0, 550, 580].enumerated() {
            model.move(Point(x, 350), at: 1040 + Double(index) * 20, down: false, input: .mouse)
        }
        #expect(model.history.isEmpty)
        #expect(model.message == "Last selection undone")
    }

    @Test func pauseDuringMouseExpertStrokeRevealsAndContinuesSlowly() {
        let model = AppModel()
        model.menuPadding = 24
        model.menuScale = 0.75
        defer { model.cancel() }
        model.begin(Point(500, 400), at: 1000, input: .mouse)
        model.move(Point(500, 350), at: 1010, down: true, input: .mouse)
        #expect(model.gesture.mode == .fast)
        model.gesture.advance(at: 1350)
        #expect(model.gesture.mode == .slow)
        #expect(model.gesture.path.map(\.name) == ["Price"])
        let option = try! #require(model.options.first { $0.direction == .right })
        let center = try! #require(model.centers.last)
        let box = model.optionRect(option, center: center)
        let point = Point(box.midX, box.midY)
        model.move(point, at: 1360, down: true, input: .mouse)
        model.gesture.advance(at: 1470)
        #expect(model.end(point, at: 1480, input: .mouse))
        #expect(model.history.last?.feedbackMessage == "You liked the price")
    }

    @Test func overlayPassesControlsThroughButKeepsTheWholeActiveStroke() {
        let model = AppModel()
        model.menuPadding = 24
        model.menuScale = 0.75
        let parent = NSView(frame: CGRect(x: 0, y: 0, width: 1100, height: 760))
        let canvas = GestureCanvasView(model: model, style: .product)
        canvas.frame = parent.bounds
        parent.addSubview(canvas)
        canvas.controlBounds = [CGRect(x: 100, y: 100, width: 44, height: 44)]
        let control = canvas.convert(NSPoint(x: 120, y: 120), to: parent)
        let surface = canvas.convert(NSPoint(x: 400, y: 400), to: parent)
        #expect(canvas.hitTest(control) == nil)
        #expect(canvas.hitTest(surface) === canvas)
        model.begin(Point(400, 400), at: 1000, input: .mouse)
        #expect(canvas.hitTest(control) === canvas)
        model.cancel()
    }

    @Test func slowOverlayRendersRequestedOpacityAndFastModeStaysClear() throws {
        let model = AppModel()
        let canvas = GestureCanvasView(model: model, style: .product)
        canvas.frame = CGRect(x: 0, y: 0, width: 1100, height: 760)
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1100, pixelsHigh: 760,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { model.cancel(); NSGraphicsContext.restoreGraphicsState() }
        model.begin(Point(500, 400), at: 1000, input: .mouse)
        model.gesture.advance(at: 1400)
        #expect(model.gesture.mode == .slow)
        for opacity in [0.0, 0.5, 1.0] {
            canvas.slowModeOverlayOpacity = opacity
            canvas.draw(canvas.bounds)
            let color = try #require(bitmap.colorAt(x: 10, y: 10))
            #expect(abs(color.alphaComponent - opacity) < 0.01)
        }
        model.cancel()
        model.begin(Point(500, 400), at: 2000, input: .mouse)
        model.move(Point(550, 400), at: 2010, down: true, input: .mouse)
        #expect(model.gesture.mode == .fast)
        canvas.draw(canvas.bounds)
        #expect(try #require(bitmap.colorAt(x: 10, y: 10)).alphaComponent == 0)
    }

}
