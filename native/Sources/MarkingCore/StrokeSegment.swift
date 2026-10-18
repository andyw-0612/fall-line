public struct StrokeSegment: Equatable, Sendable {
    public let from: Point
    public let to: Point
    public let direction: Direction
    public let startsRepeatedChoice: Bool

    public init(from: Point, to: Point, direction: Direction, startsRepeatedChoice: Bool = false) {
        self.from = from; self.to = to; self.direction = direction
        self.startsRepeatedChoice = startsRepeatedChoice
    }
}
