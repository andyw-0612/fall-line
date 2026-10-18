import Foundation

struct AccelerationSample {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: Double

    /// Apple SPU vendor-page 0xFF00 / usage 3: 22-byte report, xyz Q16 at 6/10/14.
    /// Format documented by olvvier/apple-silicon-accelerometer (MIT).
    static func decode(_ bytes: UnsafeBufferPointer<UInt8>, timestamp: Double) -> Self? {
        guard bytes.count == 22, timestamp.isFinite else { return nil }
        func axis(_ offset: Int) -> Double {
            let word = UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 |
                UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
            return Double(Int32(bitPattern: word)) / 65536
        }
        return Self(x: axis(6), y: axis(10), z: axis(14), timestamp: timestamp)
    }
}

/// High-pass acceleration, adaptive noise floor, and release/cooldown debounce.
/// Prototype tap heuristics, not a classifier of physical contact.
final class TapDetector {
    var threshold = 0.025 // g; adjustable for the laptop, table, and tapping force
    private(set) var magnitude = 0.0
    private(set) var effectiveThreshold = 0.025
    private var gravity = (x: 0.0, y: 0.0, z: 0.0)
    private var noise = 0.0
    private var started: Double?
    private var previous: Double?
    private var lastTap = -Double.infinity
    private var quietSince: Double?
    private var armed = false

    func reset() {
        started = nil; previous = nil; lastTap = -.infinity
        noise = 0; magnitude = 0; armed = false; quietSince = nil
    }

    func update(_ sample: AccelerationSample) -> Bool {
        guard sample.x.isFinite, sample.y.isFinite, sample.z.isFinite, sample.timestamp.isFinite else { reset(); return false }
        guard let previous else {
            gravity = (sample.x, sample.y, sample.z)
            started = sample.timestamp; self.previous = sample.timestamp
            return false
        }
        let dt = sample.timestamp - previous
        guard dt > 0 else { return false }
        guard dt < 0.15 else { reset(); return update(sample) }
        self.previous = sample.timestamp
        let alpha = 1 - exp(-dt / 0.025)
        gravity.x += alpha * (sample.x - gravity.x)
        gravity.y += alpha * (sample.y - gravity.y)
        gravity.z += alpha * (sample.z - gravity.z)
        magnitude = sqrt(pow(sample.x - gravity.x, 2) + pow(sample.y - gravity.y, 2) + pow(sample.z - gravity.z, 2))
        effectiveThreshold = max(threshold, noise * 6)
        // Do not teach the baseline that a tap/ringing is ordinary sensor noise.
        if magnitude < effectiveThreshold * 0.5 {
            noise += (1 - exp(-dt / 0.5)) * (magnitude - noise)
            if quietSince == nil { quietSince = sample.timestamp }
            if sample.timestamp - quietSince! >= 0.08 && sample.timestamp - lastTap >= 0.12 { armed = true }
        } else { quietSince = nil }
        guard sample.timestamp - (started ?? sample.timestamp) >= 0.5 else { return false }
        guard armed, magnitude >= effectiveThreshold, sample.timestamp - lastTap >= 0.12 else { return false }
        armed = false; lastTap = sample.timestamp; quietSince = nil
        return true
    }
}


/// Immediate single-tap action, followed by a double only for two distinct
/// impacts. Sensor quiet rearm still rejects ringing before this sequence gate.
final class PalmTapSequence {
    enum Action { case single, double }
    let window: TimeInterval = 0.35
    private var first: TimeInterval?
    func reset() { first = nil }
    func accept(_ timestamp: TimeInterval) -> Action? {
        guard timestamp.isFinite else { reset(); return nil }
        if let first {
            let interval = timestamp - first
            guard interval > 0 else { return nil }
            if interval < 0.12 { return nil }
            if interval <= window { self.first = nil; return .double }
        }
        first = timestamp
        return .single
    }
}
