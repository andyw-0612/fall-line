import Foundation

public struct OneEuroFilter {
    private var time: Double?
    private var value = 0.0, raw = 0.0, derivative = 0.0
    private let minCutoff: Double, beta: Double, resetAfter: Double, maximumInterval: Double
    public init(minCutoff: Double = 1.2, beta: Double = 0.025, resetAfter: Double = 250, maximumInterval: Double = .infinity) {
        self.minCutoff = minCutoff; self.beta = beta; self.resetAfter = resetAfter; self.maximumInterval = maximumInterval
    }
    public mutating func reset() { time = nil; derivative = 0 }
    public mutating func filter(_ value: Double, at time: Double) -> Double {
        guard let previousTime = self.time, time - previousTime <= resetAfter else {
            self.time = time; self.raw = value; self.value = value; derivative = 0; return value
        }
        guard time > previousTime else { return self.value }
        let dt = min(time - previousTime, maximumInterval) / 1000
        func alpha(_ cutoff: Double) -> Double { 1 / (1 + 1 / (2 * .pi * cutoff * dt)) }
        derivative += alpha(1) * ((value - raw) / dt - derivative)
        self.value += alpha(minCutoff + beta * abs(derivative)) * (value - self.value)
        raw = value; self.time = time
        return self.value
    }
}
