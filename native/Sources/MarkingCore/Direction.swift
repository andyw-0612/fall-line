public enum Direction: String, CaseIterable, Codable, Sendable {
    case up, right, down, left
    public var opposite: Self { switch self { case .up: .down; case .right: .left; case .down: .up; case .left: .right } }
    public var horizontal: Bool { self == .left || self == .right }
    public var sign: Double { self == .right || self == .down ? 1 : -1 }
    public var arrow: String {
        switch self { case .up: "↑"; case .right: "→"; case .down: "↓"; case .left: "←" }
    }
}
