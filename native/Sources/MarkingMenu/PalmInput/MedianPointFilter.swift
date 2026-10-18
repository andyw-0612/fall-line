import CoreGraphics

/// Causal three-frame coordinate median. Rejects isolated landmark spikes at
/// the cost of roughly one frame of latency during continuous movement.
final class MedianPointFilter {
    private var points: [CGPoint] = []
    func reset(at point: CGPoint? = nil) {
        points = point.map { [$0, $0, $0] } ?? []
    }
    func filter(_ point: CGPoint) -> CGPoint {
        points.append(point)
        if points.count > 3 { points.removeFirst() }
        return CGPoint(x: points.map(\.x).sorted()[points.count / 2],
            y: points.map(\.y).sorted()[points.count / 2])
    }
}
