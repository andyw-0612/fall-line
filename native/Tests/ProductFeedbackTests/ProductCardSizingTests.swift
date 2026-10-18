import AppKit
import CoreText
import SwiftUI
import Testing
@testable import MarkingMenu

@MainActor struct ProductCardSizingTests {
    private func size<V: View>(_ view: V) -> CGSize {
        NSHostingView(rootView: view).fittingSize
    }
    @Test func catalogueTextFitsWithoutOverlappingCards() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        CTFontManagerRegisterFontsForURL(root.appendingPathComponent("Resources/Outfit.ttf") as CFURL, .process, nil)
        let data = try Data(contentsOf: root.appendingPathComponent("Build/Marking Menu.app/Contents/Resources/Catalogue/data/enriched-450/catalogue.json"))
        let records = try JSONDecoder().decode(CatalogueDocument.self, from: data).products
        let session = CatalogueSession(); session.records = records
        // Cover the longest titles/descriptions and every distinct brand.
        let longest = records.sorted { $0.title.count > $1.title.count }.prefix(20)
        var selected = Dictionary(uniqueKeysWithValues: longest.map { ($0.id, $0) })
        var brands = Set<String>()
        for record in records where brands.insert(record.brand?.name ?? "Brand not listed").inserted { selected[record.id] = record }
        for record in records.sorted(by: { ($0.descriptions["style"] ?? "").count > ($1.descriptions["style"] ?? "").count }).prefix(5) { selected[record.id] = record }
        for record in selected.values {
            let product = try #require(session.product(.init(id: record.id, reason: "A longer explanation of how this product matches the original shopping request.", intent_match: .init(status: "partial", reason: "A longer explanation of how this product matches the original shopping request.", criteria: ["A supported criterion that includes a longer product detail", "Another supported criterion with a longer description"])) ))
            let sizes: [ProductCardRole: CGSize] = [
                .product: size(ProductHeroCard(product: product)),
                .brand: size(ProductDetailCard(kind: .brand, product: product)),
                .rating: size(ProductDetailCard(kind: .rating, product: product)),
                .review: size(ProductDetailCard(kind: .review, product: product)),
                .matches: size(ProductDetailCard(kind: .matches, product: product)),
                .description: size(ProductDetailCard(kind: .description, product: product))
            ]
            for variation in 0..<ProductCardLayout.variationCount {
                let layout = ProductCardLayout(productID: product.id, variation: variation, sizes: sizes)
                let centers: [ProductCardRole: CGPoint] = [.product: ProductCardLayout.productCenter, .brand: layout.brand, .rating: layout.rating, .review: layout.review, .matches: layout.matches, .description: layout.features]
                let rectangles = centers.map { role, center in
                    let dimensions = sizes[role]!
                    return (role, CGRect(x: center.x - dimensions.width/2, y: center.y - dimensions.height/2, width: dimensions.width, height: dimensions.height))
                }
                for (role, rectangle) in rectangles {
                    #expect(rectangle.minX >= 24 && rectangle.maxX <= 1500 && rectangle.minY >= 24 && rectangle.maxY <= 1066, "\(product.title): \(role) must fit the canvas: \(rectangle)")
                    for (otherRole, otherRectangle) in rectangles where role != otherRole {
                        #expect(!rectangle.insetBy(dx: -10, dy: -10).intersects(otherRectangle), "\(product.title): \(role) overlaps \(otherRole)")
                    }
                }
            }
        }
        let marc = ProductDetailCard(kind: .brand, product: ShoppingProduct(id: "brand-test", brand: "Marc Nolan", title: "Test", price: "$1", originalPrice: "", rating: "—", ratingCount: "0", summary: "", description: "", features: "", matches: [], reviews: [], imageTint: .white))
        let measured = size(marc)
        let text = ("Marc Nolan" as NSString).size(withAttributes: [.font: StartupStyle.headingNSFont(size: 52)])
        #expect(measured.width >= text.width + 79)
    }
}
