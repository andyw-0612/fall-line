import CoreGraphics

/// Camera-input constraint, not a menu recognizer. Project onto one axis at a
/// time; a spatial lookback and dominance margin distinguish a turn from jitter.
final class CardinalPathFilter {
    var turnDistance: CGFloat = 24
    var maximumTurns = 2
    private var direction: CGPoint?
    private var rawAnchor = CGPoint.zero
    private var outputAnchor = CGPoint.zero
    private var output = CGPoint.zero
    private var progress: CGFloat = 0
    private var history: [CGPoint] = []
    private var turns = 0
    private(set) var isFinished = false

    func reset(at point: CGPoint) {
        direction = nil; rawAnchor = point; outputAnchor = point; output = point
        progress = 0; history = [point]; turns = 0; isFinished = false
    }

    private func axis(_ vector: CGPoint, dominance: CGFloat) -> CGPoint? {
        let x = abs(vector.x), y = abs(vector.y)
        if x >= y * dominance && x > 0 { return CGPoint(x: vector.x > 0 ? 1 : -1, y: 0) }
        if y >= x * dominance && y > 0 { return CGPoint(x: 0, y: vector.y > 0 ? 1 : -1) }
        return nil
    }

    func update(_ point: CGPoint) -> CGPoint {
        guard !isFinished else { return output }
        let previousOutput = output
        if let previous = history.last, hypot(point.x - previous.x, point.y - previous.y) >= 3 {
            history.append(point)
            if history.count > 64 { history.removeFirst(history.count - 64) }
        }
        guard let direction else {
            let delta = CGPoint(x: point.x - rawAnchor.x, y: point.y - rawAnchor.y)
            guard hypot(delta.x, delta.y) >= 12, let chosen = axis(delta, dominance: 1.25) else { return output }
            self.direction = chosen
            progress = max(0, delta.x * chosen.x + delta.y * chosen.y)
            output = CGPoint(x: outputAnchor.x + chosen.x * progress, y: outputAnchor.y + chosen.y * progress)
            return output
        }

        let delta = CGPoint(x: point.x - rawAnchor.x, y: point.y - rawAnchor.y)
        // Suppress small backward excursions along a locked direction as well
        // as all perpendicular drift. A deliberate reversal is still a turn.
        progress = max(progress, delta.x * direction.x + delta.y * direction.y)
        output = CGPoint(x: outputAnchor.x + direction.x * progress, y: outputAnchor.y + direction.y * progress)
        if let reference = history.reversed().first(where: { hypot(point.x - $0.x, point.y - $0.y) >= turnDistance }) {
            let recent = CGPoint(x: point.x - reference.x, y: point.y - reference.y)
            if let next = axis(recent, dominance: 1.6), next != direction {
                // Two submenus allow three legs. Further turns are trailing
                // hooks, never an additional choice or drawn corner.
                if turns >= maximumTurns {
                    isFinished = true
                    output = previousOutput
                    return output
                }
                turns += 1
                let travel = max(0, recent.x * next.x + recent.y * next.y)
                // Preserve the corner and replay the distance used to confirm
                // the turn, instead of discarding the start of the second leg.
                outputAnchor = output
                rawAnchor = CGPoint(x: point.x - next.x * travel, y: point.y - next.y * travel)
                self.direction = next; progress = travel
                output = CGPoint(x: outputAnchor.x + next.x * progress, y: outputAnchor.y + next.y * progress)
                history = [rawAnchor, point]
            }
        }
        return output
    }
}
