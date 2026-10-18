import SwiftUI

struct ProductJourneyScene: View {
    @State private var cardSizes: [ProductCardRole: CGSize] = [:]
    let journey: ProductJourney
    let variation: Int
    var session: CatalogueSession? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(journey.legs) { leg in
                ProductJourneyPath(from: leg.from, to: leg.to)
                    .trim(from: 0, to: leg.progress)
                    .stroke(Color(red: 0.19, green: 0.28, blue: 0.25), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .opacity(leg.opacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            ProductSupportingCards(product: journey.current.product, variation: variation, sizes: cardSizes)
                .id(journey.current.id)
                .offset(
                    x: journey.current.position.x - ProductCardLayout.productCenter.x,
                    y: journey.current.position.y - ProductCardLayout.productCenter.y
                )
                .opacity(journey.supportingOpacity)
                .allowsHitTesting(!journey.isTransitioning)
                .accessibilityHidden(journey.supportingOpacity == 0)

            ForEach(journey.stops) { stop in
                FloatingProductCard(amplitude: 8, duration: 3.8, delay: 0.3) {
                    ProductHeroCard(product: stop.product, saved: session?.state.saved.contains(stop.product.id) ?? false, onSave: { session?.toggleSaved(stop.product.id) })
                        .measuringProductCard(.product)
                }
                .position(stop.position)
                .opacity(journey.productOpacity)
                .allowsHitTesting(stop.id == journey.currentID && !journey.isTransitioning)
                .accessibilityHidden(stop.id != journey.currentID)
            }
        }
        .frame(width: 1524, height: 1090)
        .onPreferenceChange(ProductCardSizePreferenceKey.self) { cardSizes = $0 }
    }
}
