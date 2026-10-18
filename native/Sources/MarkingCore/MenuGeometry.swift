import Foundation
import CoreGraphics

public enum MenuGeometry {
    public static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double { max(low, min(max(low, high), value)) }
    public static func snap(_ value: Double) -> Double { (value / 10).rounded() * 10 }
    public static func centers(_ stack: [GestureVertex], width: Double, height: Double) -> [Point] {
        var result: [Point] = []
        for vertex in stack {
            let point = Point(snap(clamp(vertex.point.x, 105, width - 105)), snap(clamp(vertex.point.y, 76, height - 115)))
            if let last = result.last, let incoming = vertex.incoming {
                result.append(incoming.horizontal ? Point(point.x, last.y) : Point(last.x, point.y))
            } else { result.append(point) }
        }
        return result
    }
    public static func optionRect(direction: Direction, center: Point, width: Double, height: Double, labelWidth: Double, labelHeight: Double = 30, centerGap: Double? = nil) -> CGRect {
        let horizontalOffset = centerGap.map { $0 + labelWidth / 2 } ?? 125
        let verticalOffset = centerGap.map { $0 + labelHeight / 2 } ?? 65
        let offset: Point = switch direction {
            case .up: Point(0, -verticalOffset); case .right: Point(horizontalOffset, 0); case .down: Point(0, verticalOffset); case .left: Point(-horizontalOffset, 0)
        }
        return CGRect(x: clamp(center.x + offset.x - labelWidth / 2, 10, width - labelWidth - 10),
                      y: clamp(center.y + offset.y - labelHeight / 2, 10, height - labelHeight - 18), width: labelWidth, height: labelHeight)
    }
    public static func reaches(_ direction: Direction, center: Point, point: Point, box: CGRect) -> Bool {
        let along = (direction.horizontal ? point.x - center.x : point.y - center.y) * direction.sign
        let across = abs(direction.horizontal ? point.y - center.y : point.x - center.x)
        let edge: Double = switch direction { case .up: box.maxY; case .down: box.minY; case .left: box.maxX; case .right: box.minX }
        let cutoff = max(6, (edge - (direction.horizontal ? center.x : center.y)) * direction.sign)
        return along >= cutoff && along >= across
    }
}
