import SwiftUI

@MainActor @Observable final class ProductJourney {
    private(set) var stops = [ProductJourneyStop(id: 0, product: ShoppingProduct.samples[0], position: ProductCardLayout.productCenter)]
    private(set) var legs: [ProductJourneyLeg] = []
    private(set) var currentID = 0
    private(set) var isTransitioning = false
    private(set) var camera = ProductCardLayout.productCenter
    private(set) var zoom: CGFloat = 1
    private(set) var supportingOpacity = 1.0
    private(set) var productOpacity = 1.0
    @ObservationIgnored private var transitionTask: Task<Void, Never>?

    var current: ProductJourneyStop { stops.first { $0.id == currentID } ?? stops[0] }

    init(initialProduct: ShoppingProduct = ShoppingProduct.samples[0]) {
        stops = [ProductJourneyStop(id: 0, product: initialProduct, position: ProductCardLayout.productCenter)]
    }

    func next(to product: ShoppingProduct? = nil, direction: CGFloat = 1, reduceMotion: Bool) {
        guard !isTransitioning else { return }
        isTransitioning = true
        let source = current
        let nextID = currentID + 1
        let destination = ProductJourneyStop(
            id: nextID,
            product: product ?? ShoppingProduct.samples[nextID % ShoppingProduct.samples.count],
            position: CGPoint(x: source.position.x + 1560 * direction, y: source.position.y + (nextID.isMultiple(of: 2) ? -240 : 240))
        )
        transitionTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            NSLog("Fall Line journey %d started", nextID)
            do {
                if reduceMotion {
                    try await animate(.easeOut(duration: 0.2), duration: 0.2) {
                        self.supportingOpacity = 0
                        self.productOpacity = 0
                    }
                    // Crossfade in place instead of moving the camera.
                    self.stops = [ProductJourneyStop(id: nextID, product: destination.product, position: ProductCardLayout.productCenter)]
                    self.legs = []
                    self.currentID = nextID
                    self.camera = ProductCardLayout.productCenter
                    try await animate(.easeIn(duration: 0.3), duration: 0.3) {
                        self.supportingOpacity = 1
                        self.productOpacity = 1
                    }
                } else {
                    // Keep the original 2.7-second choreography. The task clock,
                    // rather than a render-completion callback, owns progression.
                    try await animate(.easeInOut(duration: 0.35), duration: 0.35) {
                        self.zoom = 0.82
                        self.supportingOpacity = 0
                    }
                    self.stops.append(destination)
                    self.legs.append(ProductJourneyLeg(id: nextID, from: source.position, to: destination.position))
                    withAnimation(.timingCurve(0.45, 0, 0.55, 1, duration: 1.35)) {
                        self.legs[self.legs.count - 1].progress = 1
                    }
                    try await animate(.timingCurve(0.45, 0, 0.55, 1, duration: 1.45), duration: 1.45) {
                        self.camera = destination.position
                    }
                    self.currentID = nextID
                    try await animate(.easeInOut(duration: 0.15), duration: 0.15) {
                        self.legs[self.legs.count - 1].opacity = 0.2
                    }
                    try await animate(.easeInOut(duration: 0.4), duration: 0.4) { self.zoom = 1 }
                    try await animate(.easeInOut(duration: 0.35), duration: 0.35) { self.supportingOpacity = 1 }
                    // Retain the nearby path without growing the scene indefinitely.
                    self.stops = Array(self.stops.suffix(3))
                    self.legs = Array(self.legs.suffix(2))
                }
            } catch {
                // cancel() has already restored the visible state. Never let an
                // old cancelled task modify or unlock a newly started journey.
                return
            }
            self.isTransitioning = false
            self.transitionTask = nil
            NSLog("Fall Line journey %d completed", nextID)
        }
    }

    func cancel() {
        transitionTask?.cancel()
        transitionTask = nil
        stops.removeAll { $0.id > currentID }
        legs.removeAll { $0.id > currentID }
        camera = current.position
        zoom = 1
        supportingOpacity = 1
        productOpacity = 1
        isTransitioning = false
    }

    private func animate(_ animation: Animation, duration: Double, changes: () -> Void) async throws {
        try Task.checkCancellation()
        withAnimation(animation, changes)
        // SwiftUI completion callbacks can depend on the mounted/rendered view
        // tree. Missing one must never lock product navigation indefinitely.
        // A cancellation-aware monotonic sleep also releases promptly on exit.
        try await Task.sleep(for: .seconds(duration))
        try Task.checkCancellation()
    }
}
