import Foundation

public struct Point: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    public func distance(to other: Point) -> Double { hypot(x - other.x, y - other.y) }
    public static let zero = Point(0, 0)
}
