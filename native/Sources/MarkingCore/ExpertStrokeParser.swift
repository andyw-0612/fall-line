/// A sequence parser with one noise floor and stable direction sectors. Reverse travel
/// only rearms the current direction; it never navigates to a parent menu.
struct ExpertStrokeParser {
    private(set) var segments: [StrokeSegment] = []
    private let origin: Point
    private let maximumChoices: Int
    private var heading: Direction?
    private var peak: Point
    private var returnPoint: Point?
    private let noise = 3.0
    private let turnDistance = 6.0
    private let angularHysteresis = 1.4

    init(origin: Point, maximumChoices: Int) {
        self.origin = origin; self.peak = origin; self.maximumChoices = maximumChoices
    }

    mutating func add(_ point: Point) {
        // Release hooks or an extra zigzag cannot cancel a completed fast selection.
        guard segments.count < maximumChoices else { return }
        guard let heading else {
            guard origin.distance(to: point) >= turnDistance else { return }
            let dx = point.x - origin.x, dy = point.y - origin.y
            let direction: Direction = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
            choose(direction, from: origin, to: point)
            return
        }

        let anchor = returnPoint ?? peak
        let dx = point.x - anchor.x, dy = point.y - anchor.y
        let along = (heading.horizontal ? dx : dy) * heading.sign
        let across = abs(heading.horizontal ? dy : dx)
        let perpendicular: Direction = heading.horizontal ? (dy > 0 ? .down : .up) : (dx > 0 ? .right : .left)

        if returnPoint != nil {
            if along >= noise && across <= along * angularHysteresis {
                choose(heading, from: anchor, to: point, repeated: true)
            } else if across >= turnDistance && across > abs(along) * angularHysteresis {
                choose(perpendicular, from: anchor, to: point)
            } else if along < 0 && -along >= across * 0.7 {
                returnPoint = point
            }
            return
        }

        if across >= turnDistance && across > abs(along) * angularHysteresis {
            choose(perpendicular, from: peak, to: point)
        } else if along <= -noise && -along >= across * 0.7 {
            // Diagonal return flicks around 45° remain returns instead of falling
            // into a dead angle or accidentally choosing a perpendicular item.
            returnPoint = point
        } else if along > 0 && along >= across {
            peak = point
            if let last = segments.last {
                segments[segments.count - 1] = StrokeSegment(from: last.from, to: point, direction: last.direction,
                                                            startsRepeatedChoice: last.startsRepeatedChoice)
            }
        }
    }

    private mutating func choose(_ direction: Direction, from: Point, to: Point, repeated: Bool = false) {
        segments.append(StrokeSegment(from: from, to: to, direction: direction, startsRepeatedChoice: repeated))
        heading = direction; peak = to; returnPoint = nil
    }
}
