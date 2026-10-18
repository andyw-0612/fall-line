import Testing
@testable import MarkingCore

struct FeedbackMenuTests {
    private let routes: [([Direction], [String])] = [
        ([.up, .right], ["Price", "I Like It"]),
        ([.up, .left, .up], ["Price", "I Don't Like It", "Too Expensive"]),
        ([.up, .left, .down], ["Price", "I Don't Like It", "Too Cheap"]),
        ([.left, .up, .left], ["Function", "Quality", "I Don't Like It"]),
        ([.left, .up, .right], ["Function", "Quality", "I Like It"]),
        ([.left, .down, .left], ["Function", "Performance", "I Don't Like It"]),
        ([.left, .down, .right], ["Function", "Performance", "I Like It"]),
        ([.right, .up, .left], ["Product", "Brand", "I Don't Like It"]),
        ([.right, .up, .right], ["Product", "Brand", "I Like It"]),
        ([.right, .down, .left], ["Product", "Type", "I Don't Like It"]),
        ([.right, .down, .right], ["Product", "Type", "I Like It"]),
        ([.down, .left, .up], ["Aesthetic", "Color", "I Like It"]),
        ([.down, .left, .down], ["Aesthetic", "Color", "I Don't Like It"]),
        ([.down, .right, .up], ["Aesthetic", "Style", "I Like It"]),
        ([.down, .right, .down], ["Aesthetic", "Style", "I Don't Like It"]),
        ([.down, .down, .right], ["Aesthetic", "Material", "I Like It"]),
        ([.down, .down, .left], ["Aesthetic", "Material", "I Don't Like It"])
    ]

    @Test func everyDiagramPathMatchesInSlowAndFastModes() {
        for (directions, names) in routes {
            let slow = MarkingGesture()
            slow.start(.zero, at: 0)
            for (i, direction) in directions.enumerated() {
                #expect(slow.commit(direction, isBack: false, at: Double(i + 1) * 200, point: .zero))
            }
            #expect(slow.final)
            #expect(slow.finish()?.map(\.name) == names)
            for length in [10.0, 70, 200] {
                let fast = MarkingGesture(adaptive: true, canEnter: { _, _, _ in false })
                var point = Point(500, 500), time = 0.0, previous: Direction?
                fast.start(point, at: time)
                func move(_ direction: Direction, _ distance: Double) {
                    point = direction.horizontal ? Point(point.x + direction.sign * distance, point.y) : Point(point.x, point.y + direction.sign * distance)
                    time += 10; fast.move(point, at: time)
                }
                for direction in directions {
                    if direction == previous { move(direction.opposite, 4) }
                    move(direction, length); previous = direction
                }
                #expect(fast.finish()?.map(\.name) == names)
            }
        }
    }

    @Test func theTreeHasExactlyTheSeventeenFinalOptionsAndNoExtraChoices() {
        var ids = Set<String>(), leafPaths: [[String]] = []
        func visit(_ node: MenuNode, incoming: Direction?, path: [String]) {
            #expect(ids.insert(node.id).inserted)
            if node.isLeaf { leafPaths.append(path); return }
            let choices = node.choices(incoming: incoming)
            #expect(choices.count == node.children.count + (incoming == nil ? 0 : 1))
            #expect(choices.allSatisfy { $0.isBack || $0.node != nil })
            #expect(choices.filter(\.isBack).first?.direction == incoming?.opposite)
            for child in node.children { visit(child, incoming: child.direction, path: path + [child.name]) }
        }
        visit(.root, incoming: nil, path: [])
        #expect(leafPaths.count == 17)
        #expect(Set(leafPaths.map { $0.joined(separator: " → ") }) == Set(routes.map { $0.1.joined(separator: " → ") }))
    }

    @Test func emptyDirectionsDoNothingAndBackReturnsToTheParent() {
        let gesture = MarkingGesture()
        gesture.start(.zero, at: 0)
        gesture.commit(.right, isBack: false, at: 1, point: .zero)
        #expect(!gesture.commit(.right, isBack: false, at: 2, point: Point(100, 0)))
        #expect(gesture.path.map(\.name) == ["Product"])
        #expect(gesture.pointer == .zero)
        gesture.commit(.up, isBack: false, at: 3, point: .zero)
        gesture.commit(.down, isBack: true, at: 4, point: .zero)
        #expect(gesture.path.map(\.name) == ["Product"])
        #expect(gesture.current?.node.choices(incoming: .right).first(where: { $0.direction == .up })?.name == "Brand")
    }

    @Test func priceLikeIsFinalAfterTwoChoicesAndDislikeNeedsAReason() {
        let gesture = MarkingGesture()
        gesture.start(.zero, at: 0)
        gesture.commit(.up, isBack: false, at: 1, point: .zero)
        gesture.commit(.left, isBack: false, at: 2, point: .zero)
        #expect(!gesture.final)
        #expect(gesture.finish() == nil)
        let fast = MarkingGesture(adaptive: true)
        fast.start(.zero, at: 0)
        fast.move(Point(0, -100), at: 10); fast.move(Point(100, -100), at: 20)
        fast.move(Point(100, 0), at: 30)
        #expect(fast.finish()?.map(\.name) == ["Price", "I Like It"])
    }
}
