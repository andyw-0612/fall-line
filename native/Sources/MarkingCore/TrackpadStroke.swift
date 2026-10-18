public struct TrackpadStroke {
    public enum Action: Equatable { case begin(Point), move(Point), finish(Point), cancel }
    private var previous: Point?
    private var pointer = Point.zero
    private var blocked = false
    public var sensitivity = 0.75
    public init() {}
    public mutating func reset() { previous = nil; blocked = false }
    public mutating func invalidateUntilLift() { previous = nil; blocked = true }
    // Receives actual two-finger contact positions, never synthetic scroll events.
    public mutating func update(count: Int, centroid: Point?, origin: Point) -> [Action] {
        if count == 0 { let result: [Action] = previous != nil ? [.finish(pointer)] : []; reset(); return result }
        if count > 2 { let result: [Action] = previous != nil ? [.cancel] : []; previous = nil; blocked = true; return result }
        if count < 2 {
            let result: [Action] = previous != nil ? [.finish(pointer)] : []
            if previous != nil { blocked = true }; previous = nil; return result
        }
        guard !blocked, let centroid else { return [] }
        guard let last = previous else { previous = centroid; pointer = origin; return [.begin(pointer)] }
        previous = centroid
        pointer = Point(pointer.x + (centroid.x - last.x) * 1000 * sensitivity,
                        pointer.y - (centroid.y - last.y) * 1000 * sensitivity)
        return [.move(pointer)]
    }
}
