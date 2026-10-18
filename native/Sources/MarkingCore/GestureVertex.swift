public struct GestureVertex: Sendable {
    public var node: MenuNode
    public var incoming: Direction?
    public var point: Point
    public init(node: MenuNode, incoming: Direction?, point: Point) {
        self.node = node; self.incoming = incoming; self.point = point
    }
}
