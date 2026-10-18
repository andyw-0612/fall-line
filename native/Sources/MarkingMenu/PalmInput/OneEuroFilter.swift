import Foundation

// One Euro position filter; see https://gery.casiez.net/1euro/
final class LowPassFilter {
    private var y: Double?
    private var s: Double?

    func filter(value: Double, alpha: Double) -> Double {
        let result: Double
        if let prev = s {
            result = alpha * value + (1.0 - alpha) * prev
        } else {
            result = value
        }
        y = value
        s = result
        return result
    }

    var lastFiltered: Double? { s }
    func reset() { y = nil; s = nil }
}

final class OneEuroFilter {
    var freq: Double
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double
    private let x = LowPassFilter()
    private let dx = LowPassFilter()
    private var lastTime: Double?

    init(freq: Double = 30.0, minCutoff: Double = 1.5, beta: Double = 20.0, dCutoff: Double = 1.0) {
        self.freq = max(1.0, freq)
        self.minCutoff = max(0.01, minCutoff)
        self.beta = max(0.0, beta)
        self.dCutoff = max(0.01, dCutoff)
    }

    private func alpha(cutoff: Double) -> Double {
        let te = 1.0 / freq
        let tau = 1.0 / (2.0 * .pi * cutoff)
        return 1.0 / (1.0 + tau / te)
    }

    func filter(_ value: Double, timestamp: Double) -> Double {
        if let last = lastTime, timestamp > last {
            let dt = timestamp - last
            if dt > 0 && dt < 1.0 { freq = 1.0 / dt }
        }
        lastTime = timestamp
        let dValue = x.lastFiltered != nil ? (value - x.lastFiltered!) * freq : 0.0
        let edValue = dx.filter(value: dValue, alpha: alpha(cutoff: dCutoff))
        let cutoff = minCutoff + beta * abs(edValue)
        return x.filter(value: value, alpha: alpha(cutoff: cutoff))
    }

    func reset() {
        x.reset()
        dx.reset()
        lastTime = nil
    }
}

