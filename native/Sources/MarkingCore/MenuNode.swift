public struct MenuNode: Equatable, Sendable {
    public let id: String
    public let name: String
    public let children: [MenuNode]
    public let direction: Direction?
    public init(id: String, name: String, children: [MenuNode], direction: Direction? = nil) {
        self.id = id; self.name = name; self.children = children; self.direction = direction
    }
    public var isLeaf: Bool { children.isEmpty }
    public func choices(incoming: Direction?) -> [MenuChoice] {
        if children.contains(where: { $0.direction != nil }) {
            return Direction.allCases.compactMap { direction in
                if incoming?.opposite == direction { return MenuChoice(direction: direction, node: nil, isBack: true) }
                guard let node = children.first(where: { $0.direction == direction }) else { return nil }
                return MenuChoice(direction: direction, node: node)
            }
        }
        var index = 0
        return Direction.allCases.map { direction in
            if incoming?.opposite == direction { return MenuChoice(direction: direction, node: nil, isBack: true) }
            let node = children.indices.contains(index) ? children[index] : nil
            index += 1
            return MenuChoice(direction: direction, node: node, isBack: false)
        }
    }
    public static let root: MenuNode = {
        func node(_ id: String, _ name: String, _ direction: Direction, _ children: [MenuNode] = []) -> MenuNode {
            MenuNode(id: id, name: name, children: children, direction: direction)
        }
        func opinion(_ id: String, _ name: String, _ direction: Direction, vertical: Bool = false) -> MenuNode {
            node(id, name, direction, [
                node(id + "-like", "I Like It", vertical ? .up : .right),
                node(id + "-dislike", "I Don't Like It", vertical ? .down : .left)
            ])
        }
        return MenuNode(id: "root", name: "Explore", children: [
            node("price", "Price", .up, [
                node("price-dislike", "I Don't Like It", .left, [
                    node("price-too-expensive", "Too Expensive", .up),
                    node("price-too-cheap", "Too Cheap", .down)
                ]),
                node("price-like", "I Like It", .right)
            ]),
            node("product", "Product", .right, [
                opinion("product-brand", "Brand", .up),
                opinion("product-type", "Type", .down)
            ]),
            node("aesthetic", "Aesthetic", .down, [
                opinion("aesthetic-color", "Color", .left, vertical: true),
                opinion("aesthetic-style", "Style", .right, vertical: true),
                opinion("aesthetic-material", "Material", .down)
            ]),
            node("function", "Function", .left, [
                opinion("function-quality", "Quality", .up),
                opinion("function-performance", "Performance", .down)
            ])
        ])
    }()
}
