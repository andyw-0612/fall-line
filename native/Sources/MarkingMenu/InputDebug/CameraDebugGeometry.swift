import CoreGraphics
import MarkingCore

enum CameraDebugGeometry {
    static let connections: [(Int, Int)] = [
        (0,1),(1,2),(2,3),(3,4), (0,5),(5,6),(6,7),(7,8),
        (5,9),(9,10),(10,11),(11,12), (9,13),(13,14),(14,15),(15,16),
        (13,17),(0,17),(17,18),(18,19),(19,20)
    ]

    static func videoRect(size: CGSize, aspect: Double) -> CGRect {
        guard aspect.isFinite, aspect > 0 else { return .zero }
        let width = min(size.width, size.height * aspect)
        let height = width / aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    static func project(_ point: Point, into rect: CGRect, deskView: Bool) -> CGPoint {
        let point = HandPose.interactionPoint(point, deskView: deskView)
        return CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }
}
