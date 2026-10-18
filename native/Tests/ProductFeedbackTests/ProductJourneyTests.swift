import SwiftUI
import Testing
@testable import MarkingMenu

@MainActor struct ProductJourneyTests {
    @Test func journeysFinishCenteredAndIgnoreRepeatedNextRequests() async throws {
        let journey = ProductJourney()
        for index in 1...3 {
            journey.next(reduceMotion: false)
            journey.next(reduceMotion: false)
            #expect(journey.isTransitioning)
            try await finish(journey)
            #expect(journey.currentID == index)
            #expect(journey.camera == journey.current.position)
            #expect(journey.zoom == 1)
            #expect(journey.supportingOpacity == 1)
            #expect(journey.legs.last?.progress == 1)
            #expect(journey.legs.last?.opacity == 0.2)
        }
        #expect(journey.stops.count == 3)
        #expect(journey.legs.count == 2)
    }

    @Test func reduceMotionSwitchesProductsWithoutCameraMovement() async throws {
        let journey = ProductJourney()
        journey.next(reduceMotion: true)
        try await finish(journey)
        #expect(journey.current.product.id == ShoppingProduct.samples[1].id)
        #expect(journey.camera == ProductCardLayout.productCenter)
        #expect(journey.zoom == 1)
        #expect(journey.productOpacity == 1)
        #expect(journey.supportingOpacity == 1)
        #expect(journey.stops.count == 1)
        #expect(journey.legs.isEmpty)
    }

    @Test func cancellationKeepsTheCurrentProductAndAllowsAnotherJourney() async throws {
        let journey = ProductJourney()
        journey.next(reduceMotion: false)
        journey.cancel()
        await Task.yield()
        #expect(!journey.isTransitioning)
        #expect(journey.currentID == 0)
        #expect(journey.stops.count == 1)
        #expect(journey.legs.isEmpty)
        journey.next(reduceMotion: true)
        try await finish(journey)
        #expect(journey.currentID == 1)
    }

    @Test func choreographyAdvancesWithoutAViewCompletionCallback() async throws {
        // No SwiftUI view is mounted. Rendering completion must not own the
        // lifetime of this navigation state machine on any macOS version.
        let journey = ProductJourney()
        let clock = ContinuousClock()
        let start = clock.now
        journey.next(reduceMotion: false)
        try await reachTravel(journey)
        #expect(journey.isTransitioning)
        #expect(journey.stops.count == 2)
        #expect(journey.currentID == 0, "Travel should precede selecting the destination")
        try await finish(journey)
        #expect(clock.now - start >= .seconds(2.6), "Preserve the complete transition choreography")
        #expect(journey.currentID == 1)
        #expect(journey.zoom == 1)
        #expect(journey.supportingOpacity == 1)
    }

    @Test func cancellingDuringTravelDoesNotInterruptTheNextJourney() async throws {
        let journey = ProductJourney()
        journey.next(reduceMotion: false)
        try await reachTravel(journey)
        #expect(journey.stops.count == 2)
        journey.cancel()
        #expect(journey.currentID == 0)
        #expect(journey.stops.count == 1)
        journey.next(reduceMotion: true)
        try await finish(journey)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!journey.isTransitioning)
        #expect(journey.currentID == 1)
        #expect(journey.stops.count == 1)
        #expect(journey.productOpacity == 1)
        #expect(journey.supportingOpacity == 1)
    }

    private func reachTravel(_ journey: ProductJourney) async throws {
        // Other main-actor tests can delay task startup (e.g. decoding450 images).
        // Wait for the real phase instead of assuming it began450ms ago.
        for _ in 0..<200 {
            if journey.stops.count == 2 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(journey.stops.count == 2, "The travel phase must start")
    }

    private func finish(_ journey: ProductJourney) async throws {
        for _ in 0..<140 {
            if !journey.isTransitioning { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(!journey.isTransitioning, "The complete camera and reveal sequence must finish")
        journey.cancel()
    }
}
