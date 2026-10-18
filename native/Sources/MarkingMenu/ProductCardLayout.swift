import Foundation

/// Stable per-product arrangements within separate, non-overlapping card regions.
struct ProductCardLayout {
    static let variationCount = 12
    static let productCenter = CGPoint(x: 762, y: 545)

    let brand: CGPoint
    let rating: CGPoint
    let review: CGPoint
    let matches: CGPoint
    let features: CGPoint

    init(productID: String, variation: Int, sizes: [ProductCardRole: CGSize] = [:]) {
        // Unlike Swift's Hasher, this seed stays the same between app launches.
        var seed = productID.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        seed &+= UInt64(truncatingIfNeeded: variation) &* 0x9E3779B97F4A7C15

        func coordinate(in range: ClosedRange<CGFloat>) -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let fraction = CGFloat(seed >> 11) / CGFloat(UInt64.max >> 11)
            return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        }

        let brandSize = sizes[.brand] ?? CGSize(width: 320, height: 112)
        let ratingSize = sizes[.rating] ?? CGSize(width: 340, height: 94)
        let reviewSize = sizes[.review] ?? CGSize(width: 366, height: 240)
        let matchSize = sizes[.matches] ?? CGSize(width: 366, height: 290)
        let descriptionSize = sizes[.description] ?? CGSize(width: 420, height: 240)
        let heroSize = sizes[.product] ?? CGSize(width: 440, height: 540)
        let hero = CGRect(x: Self.productCenter.x - heroSize.width / 2,
                          y: Self.productCenter.y - heroSize.height / 2,
                          width: heroSize.width, height: heroSize.height)
        let padding: CGFloat = 32
        let gap: CGFloat = 40 // Includes the ambient bobbing of both cards.
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            min(max(value, low), max(low, high))
        }
        func leftX(_ desired: CGFloat, _ size: CGSize) -> CGFloat {
            clamp(desired, padding + size.width / 2, hero.minX - gap - size.width / 2)
        }
        func rightX(_ desired: CGFloat, _ size: CGSize) -> CGFloat {
            clamp(desired, hero.maxX + gap + size.width / 2, 1524 - padding - size.width / 2)
        }

        let brandX = clamp(coordinate(in: 520...820), padding + brandSize.width / 2, 1524 - padding - brandSize.width / 2)
        let brandY = clamp(coordinate(in: 140...175), padding + brandSize.height / 2, hero.minY - gap - brandSize.height / 2)
        brand = CGPoint(x: brandX, y: brandY)

        let ratingX = leftX(coordinate(in: 250...340), ratingSize)
        var ratingY = coordinate(in: 350...560)
        let reviewX = rightX(coordinate(in: 1190...1270), reviewSize)
        var reviewY = coordinate(in: 220...460)
        let matchX = leftX(coordinate(in: 250...330), matchSize)
        var matchY = coordinate(in: 780...880)
        let descriptionX = rightX(coordinate(in: 1210...1260), descriptionSize)
        var descriptionY = coordinate(in: 760...880)

        // Fit measured text heights while keeping each card in its familiar area.
        matchY = min(1090 - padding - matchSize.height / 2,
                     max(matchY, ratingY + ratingSize.height / 2 + gap + matchSize.height / 2))
        ratingY = min(ratingY, matchY - matchSize.height / 2 - gap - ratingSize.height / 2)
        let brandRight = brandX + brandSize.width / 2
        let reviewLeft = reviewX - reviewSize.width / 2
        let reviewTop = brandRight + gap > reviewLeft ? brandY + brandSize.height / 2 + gap : padding
        reviewY = max(reviewY, reviewTop + reviewSize.height / 2)
        descriptionY = min(1090 - padding - descriptionSize.height / 2,
                           max(descriptionY, reviewY + reviewSize.height / 2 + gap + descriptionSize.height / 2))
        reviewY = min(reviewY, descriptionY - descriptionSize.height / 2 - gap - reviewSize.height / 2)
        rating = CGPoint(x: ratingX, y: ratingY)
        review = CGPoint(x: reviewX, y: reviewY)
        matches = CGPoint(x: matchX, y: matchY)
        features = CGPoint(x: descriptionX, y: descriptionY)
    }
}
