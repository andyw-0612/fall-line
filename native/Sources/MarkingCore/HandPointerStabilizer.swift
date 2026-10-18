import Foundation

/// Normalized camera coordinates shared by the preview and gesture cursor.
public struct HandPointerStabilizer {
    public enum Sample: Equatable {
        case tracked(Point), held(Point), lost
        public var point: Point? {
            switch self { case let .tracked(point), let .held(point): point; case .lost: nil }
        }
    }
    public static let holdDuration = 450.0
    // Filter in a fixed 1000-unit space so smoothing does not depend on window size.
    private var x = OneEuroFilter(minCutoff: 0.8, beta: 0.006, resetAfter: 500, maximumInterval: 50)
    private var y = OneEuroFilter(minCutoff: 0.8, beta: 0.006, resetAfter: 500, maximumInterval: 50)
    private var lastSeen: Double?
    private var position: Point?
    public init() {}

    public mutating func reset() {
        x.reset(); y.reset(); lastSeen = nil; position = nil
    }

    public mutating func update(_ tip: Point?, at time: Double) -> Sample {
        guard let tip, tip.x.isFinite, tip.y.isFinite,
              (0...1).contains(tip.x), (0...1).contains(tip.y) else {
            if let lastSeen, let position, time - lastSeen <= Self.holdDuration { return .held(position) }
            reset(); return .lost
        }
        if let lastSeen, time - lastSeen > Self.holdDuration { reset() }
        let filtered = Point(x.filter(tip.x * 1000, at: time) / 1000, y.filter(tip.y * 1000, at: time) / 1000)
        // A small positional deadband prevents sub-pixel wobble without blocking accumulated motion.
        if let position, filtered.distance(to: position) < 0.0015 {
            self.lastSeen = time
            return .tracked(position)
        }
        position = filtered; lastSeen = time
        return .tracked(filtered)
    }
}
