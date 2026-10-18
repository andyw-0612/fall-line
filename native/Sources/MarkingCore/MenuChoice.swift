public struct MenuChoice: Sendable {
    public let direction: Direction
    public let node: MenuNode?
    public let isBack: Bool
    public var name: String { isBack ? "Back" : node?.name ?? "" }
    public init(direction: Direction, node: MenuNode?, isBack: Bool = false) {
        self.direction = direction; self.node = node; self.isBack = isBack
    }
}
