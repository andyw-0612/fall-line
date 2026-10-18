import Foundation
import CoreGraphics

/// A single fingertip supplies movement. The unmodified JS recognizer decides
/// completion; its selection callback locks this adapter until the next tap.
final class IndexFingerInput {
    enum State { case drawing, waitingForTap, awaitingAnchor }
    private(set) var state: State = .waitingForTap
    private(set) var preview: CGPoint?
    private(set) var lastPosition = CGPoint.zero
    private(set) var isFrozen = false
    var mirrored = false
    var maximumFrameGap: TimeInterval = 0.15
    var smoothing = true
    var gain: CGFloat = 700
    var snapDirections = true
    let cardinal = CardinalPathFilter()
    private let x = OneEuroFilter()
    private let y = OneEuroFilter()
    private let median = MedianPointFilter()
    private var anchor = CGPoint.zero
    private var origin = CGPoint.zero
    private var latestRaw: CGPoint?
    private var lastTimestamp: Double?
    private var tapTimestamp: Double?
    // Exclude the contact transient; anchor on the first capture after this guard.
    // This is a time guard, not a stillness requirement or movement dead zone.
    let touchdownGuard = 0.030

    func configureFilter(cutoff: Double, beta: Double) {
        x.minCutoff = cutoff; y.minCutoff = cutoff
        x.beta = beta; y.beta = beta
    }

    func complete() {
        state = .waitingForTap
        tapTimestamp = nil
        isFrozen = false
    }

    /// The JS recognizer has accepted its first complete menu path.
    /// Freeze both the drawn trail and input until confirmation/cancellation.
    func freeze() { if state == .drawing { isFrozen = true } }

    /// Sensor and capture timestamps must use host monotonic time. The most
    /// recently delivered pose may predate impact, so it must not be the anchor.
    @discardableResult func tap(origin: CGPoint, timestamp: Double) -> [PinchEvent] {
        guard state == .waitingForTap, latestRaw != nil, lastTimestamp != nil, timestamp.isFinite else { return [] }
        self.origin = origin
        tapTimestamp = timestamp
        state = .awaitingAnchor
        return []
    }

    @discardableResult func cancel() -> [PinchEvent] {
        let events = state == .drawing ? [PinchEvent(kind: .cancel, position: lastPosition)] : []
        complete()
        latestRaw = nil; preview = nil; lastTimestamp = nil; x.reset(); y.reset(); median.reset()
        return events
    }

    @discardableResult func update(_ point: CGPoint?, aspect: CGFloat, timestamp: Double, origin: CGPoint) -> [PinchEvent] {
        guard let point, point.x.isFinite, point.y.isFinite, aspect.isFinite, aspect > 0, timestamp.isFinite else { return cancel() }
        if let previous = lastTimestamp {
            if timestamp <= previous { return [] }
            if timestamp - previous > maximumFrameGap { return cancel() }
        }
        lastTimestamp = timestamp
        let raw = CGPoint(x: point.x * aspect, y: point.y)
        latestRaw = raw
        if state == .waitingForTap {
            let clean = smoothing ? median.filter(raw) : raw
            preview = CGPoint(x: (smoothing ? x.filter(Double(clean.x), timestamp: timestamp) : Double(raw.x)) / aspect,
                y: smoothing ? y.filter(Double(clean.y), timestamp: timestamp) : Double(raw.y))
            return []
        }
        if state == .awaitingAnchor {
            preview = point
            guard let tapTimestamp, timestamp >= tapTimestamp + touchdownGuard else { return [] }
            anchor = raw; lastPosition = self.origin
            cardinal.reset(at: self.origin)
            x.reset(); y.reset()
            median.reset(at: raw)
            _ = x.filter(Double(raw.x), timestamp: timestamp)
            _ = y.filter(Double(raw.y), timestamp: timestamp)
            self.tapTimestamp = nil
            state = .drawing
            return [PinchEvent(kind: .begin, position: self.origin)]
        }
        if isFrozen { return [] }
        let clean = smoothing ? median.filter(raw) : raw
        let filtered = CGPoint(x: smoothing ? x.filter(Double(clean.x), timestamp: timestamp) : Double(raw.x),
            y: smoothing ? y.filter(Double(clean.y), timestamp: timestamp) : Double(raw.y))
        let mapped = CGPoint(x: self.origin.x + (filtered.x - anchor.x) * gain * (mirrored ? -1 : 1),
            y: self.origin.y - (filtered.y - anchor.y) * gain)
        lastPosition = snapDirections ? cardinal.update(mapped) : mapped
        // Draw the same accepted input on the camera trail and the menu. The
        // raw skeleton still exposes model jitter for comparison.
        preview = CGPoint(x: (anchor.x + (lastPosition.x - self.origin.x) / (gain * (mirrored ? -1 : 1))) / aspect,
            y: anchor.y - (lastPosition.y - self.origin.y) / gain)
        if snapDirections && cardinal.isFinished {
            complete()
            return [PinchEvent(kind: .end, position: lastPosition)]
        }
        return [PinchEvent(kind: .move, position: lastPosition)]
    }
}
