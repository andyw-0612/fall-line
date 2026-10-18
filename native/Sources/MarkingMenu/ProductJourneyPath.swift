import SwiftUI

struct ProductJourneyPath: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        let elbow = from.x + 600
        let sign: CGFloat = to.y >= from.y ? 1 : -1
        let radius: CGFloat = 28
        var path = Path()
        path.move(to: CGPoint(x: from.x + 220, y: from.y))
        path.addLine(to: CGPoint(x: elbow - radius, y: from.y))
        path.addQuadCurve(to: CGPoint(x: elbow, y: from.y + sign * radius), control: CGPoint(x: elbow, y: from.y))
        path.addLine(to: CGPoint(x: elbow, y: to.y - sign * radius))
        path.addQuadCurve(to: CGPoint(x: elbow + radius, y: to.y), control: CGPoint(x: elbow, y: to.y))
        path.addLine(to: CGPoint(x: to.x - 220, y: to.y))
        return path
    }
}
