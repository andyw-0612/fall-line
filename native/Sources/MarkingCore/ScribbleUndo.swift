import Foundation

public struct ScribbleUndo {
    private struct Run { var horizontal: Bool; var sign: Double; var distance: Double; var start: Double }
    private var id: Int?
    private var until = 0.0
    private var point = Point.zero
    private var runs: [Run] = []
    public init() {}
    public mutating func arm(id: Int, at time: Double, point: Point) {
        self.id = id; until = time + 1500; self.point = point; runs = []
    }
    public mutating func clear() { id = nil; runs = [] }
    public mutating func move(_ point: Point, at time: Double) -> Int? {
        guard let id, time <= until else { clear(); return nil }
        let dx = point.x - self.point.x, dy = point.y - self.point.y
        guard hypot(dx, dy) >= 3 else { return nil }
        self.point = point
        let horizontal = abs(dx) > abs(dy) * 1.4, vertical = abs(dy) > abs(dx) * 1.4
        guard horizontal || vertical else { return nil }
        let delta = horizontal ? dx : dy, sign = delta > 0 ? 1.0 : -1.0
        runs.removeAll { time - $0.start > 500 }
        if let last = runs.last, last.horizontal != horizontal { runs = [] }
        if let last = runs.last, last.sign == sign { runs[runs.count - 1].distance += abs(delta) }
        else { runs.append(Run(horizontal: horizontal, sign: sign, distance: abs(delta), start: time)) }
        let recent = runs.suffix(3)
        if recent.count == 3 && recent.allSatisfy({ $0.distance >= 10 }) && recent.reduce(0, { $0 + $1.distance }) >= 60 {
            clear(); return id
        }
        return nil
    }
}
