import SwiftUI

struct ProductSupportingCards: View {
    let product: ShoppingProduct
    let variation: Int
    var sizes: [ProductCardRole: CGSize] = [:]

    var body: some View {
        let layout = ProductCardLayout(productID: product.id, variation: variation, sizes: sizes)
        ZStack(alignment: .topLeading) {
            FloatingProductCard(amplitude: 6, duration: 4.2) {
                ProductDetailCard(kind: .brand, product: product)
                    .measuringProductCard(.brand)
            }
            .position(layout.brand)

            FloatingProductCard(amplitude: 6, duration: 4.6, delay: 0.8) {
                ProductDetailCard(kind: .rating, product: product)
                    .measuringProductCard(.rating)
            }
            .position(layout.rating)

            FloatingProductCard(amplitude: 9, duration: 4.1, delay: 0.5) {
                ProductDetailCard(kind: .review, product: product)
                    .measuringProductCard(.review)
            }
            .position(layout.review)

            FloatingProductCard(amplitude: 8, duration: 4.8, delay: 1.1) {
                ProductDetailCard(kind: .matches, product: product)
                    .measuringProductCard(.matches)
            }
            .position(layout.matches)

            FloatingProductCard(amplitude: 6, duration: 3.9, delay: 1.4) {
                ProductDetailCard(kind: .description, product: product)
                    .measuringProductCard(.description)
            }
            .position(layout.features)
        }
        .frame(width: 1524, height: 1090)
    }
}
