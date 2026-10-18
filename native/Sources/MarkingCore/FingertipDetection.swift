import Foundation

public struct FingertipDetection: Sendable, Equatable {
    public let bounds: CGRect
    public let confidence: Double
    public var point: Point { Point(bounds.midX, bounds.midY) }
    public init(bounds: CGRect, confidence: Double) { self.bounds = bounds; self.confidence = confidence }
}
