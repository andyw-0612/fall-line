public struct HandPose: Sendable {
    public var indexExtended: Bool
    public var pointing: Bool
    public var pinched: Bool
    public init(indexExtended: Bool, pointing: Bool, pinched: Bool) {
        self.indexExtended = indexExtended; self.pointing = pointing; self.pinched = pinched
    }
    public init(points: [Point]) {
        func extended(_ tip: Int, _ joint: Int, _ ratio: Double = 1.15) -> Bool {
            points[tip].distance(to: points[0]) > points[joint].distance(to: points[0]) * ratio
        }
        guard points.count == 21 else { self.init(indexExtended: false, pointing: false, pinched: false); return }
        self.init(indexExtended: extended(8, 6), pointing: extended(8, 6) && !extended(16, 14, 1.05) && !extended(20, 18, 1.05),
                  pinched: points[4].distance(to: points[12]) < 0.05)
    }
    public static func map(_ tip: Point, width: Double, height: Double, deskView: Bool) -> Point {
        let tip = interactionPoint(tip, deskView: deskView)
        let left = deskView ? 0.0 : 0.15, top = deskView ? 0.0 : 0.25
        let spanX = deskView ? 1.0 : 0.7, spanY = deskView ? 1.0 : 0.6
        return Point(MenuGeometry.clamp((tip.x - left) / spanX, 0, 1) * width,
                     MenuGeometry.clamp((tip.y - top) / spanY, 0, 1) * height)
    }
    /// Normal cameras retain their mirrored interaction. Desk View uses the
    /// opposite horizontal orientation. Capture/inference remains unmirrored.
    public static func interactionPoint(_ tip: Point, deskView: Bool) -> Point {
        deskView ? tip : Point(1 - tip.x, tip.y)
    }
}
