public enum StrokeRecognizer {
    /// Parse the captured path in order, without whole-stroke length ratios or resampling.
    /// Recognition depends on physical direction changes, not event count or elapsed time.
    public static func segments(_ input: [Point], depth: Int = 3) -> [StrokeSegment] {
        guard depth > 0, let origin = input.first else { return [] }
        var parser = ExpertStrokeParser(origin: origin, maximumChoices: depth)
        for point in input.dropFirst() { parser.add(point) }
        return parser.segments
    }

    public static func vertices(_ points: [Point], root: MenuNode = .root) -> [GestureVertex]? {
        guard let origin = points.first else { return nil }
        var stack = [GestureVertex(node: root, incoming: nil, point: origin)]
        for segment in segments(points) {
            guard let current = stack.last else { return nil }
            if current.node.isLeaf { break }
            guard let next = current.node.choices(incoming: current.incoming).first(where: { $0.direction == segment.direction })?.node else { return nil }
            stack.append(GestureVertex(node: next, incoming: segment.direction, point: segment.to))
        }
        return stack
    }
}
