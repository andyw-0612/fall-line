import MarkingCore

/// Camera-only distance gate. Mouse and trackpad keep their existing recognizer.
enum PalmPathQualification {
    static func path(_ points: [Point], minimumDistance: Double) -> [MenuNode]? {
        guard minimumDistance.isFinite, minimumDistance > 0 else { return nil }
        // One extra slot lets the parser continue extending the third leg.
        let segments = StrokeRecognizer.segments(points, depth: 4)
        var node = MenuNode.root
        var incoming: Direction?
        var path: [MenuNode] = []
        for segment in segments {
            var remaining = segment.from.distance(to: segment.to)
            guard remaining >= minimumDistance else { return nil }
            // The app retains Material, whose first two choices both go down.
            // Two full step distances on that axis express its repeated choice.
            repeat {
                guard let choice = node.choices(incoming: incoming).first(where: {
                    !$0.isBack && $0.direction == segment.direction
                }), let next = choice.node else { return nil }
                node = next; incoming = segment.direction; path.append(next)
                remaining -= minimumDistance
                if node.isLeaf { return path }
            } while remaining >= minimumDistance && node.choices(incoming: incoming).contains(where: {
                !$0.isBack && $0.direction == segment.direction && $0.node != nil
            })
        }
        return nil
    }
}
