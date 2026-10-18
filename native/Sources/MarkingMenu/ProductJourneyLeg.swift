import Foundation

struct ProductJourneyLeg: Identifiable {
    let id: Int
    let from: CGPoint
    let to: CGPoint
    var progress: CGFloat = 0
    var opacity = 1.0
}
