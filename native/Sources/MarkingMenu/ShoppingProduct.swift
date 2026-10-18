import SwiftUI

struct ShoppingProduct: Identifiable {
    let id: String
    let brand: String
    let title: String
    let price: String
    let originalPrice: String
    let rating: String
    let ratingCount: String
    let summary: String
    let description: String
    let features: String
    let matches: [String]
    let reviews: [String]
    let imageTint: Color

    var fullDescription: String? = nil
    var imageURL: URL? = nil
    var productURL: URL? = nil
    var reviewLabel = "Sample review"
    var matchStatus = "strong"
    var matchReason = "Summarized from product details"

    // Local design samples until catalogue recommendations are connected.
    static let samples: [ShoppingProduct] = [
        ShoppingProduct(
            id: "sample-nike-zegama-blue", brand: "Nike", title: "Zegama Shoes — Blue",
            price: "$30", originalPrice: "$120", rating: "4.5", ratingCount: "1.1K",
            summary: "Trail-running shoes designed for\ncushioned comfort and confident grip.",
            description: "A cushioned trail shoe with a breathable mesh upper, a supportive heel, and a grippy outsole. Built for comfortable miles on varied terrain.",
            features: "Cushioned heel · Mesh · Trail grip",
            matches: ["Blue colorway", "Cushioned comfort"],
            reviews: ["“Really comfortable for long walks.”", "“Love the blue. Plenty of cushioning on the trail.”", "“Great grip and a comfortable fit.”"],
            imageTint: Color(white: 0.91)
        ),
        ShoppingProduct(
            id: "sample-hoka-speedgoat-sage", brand: "HOKA", title: "Speedgoat — Sage",
            price: "$95", originalPrice: "$155", rating: "4.7", ratingCount: "840",
            summary: "Soft cushioning and steady traction\nfor your next stretch of trail.",
            description: "A soft, supportive trail shoe with an airy mesh upper and a durable outsole. Generous cushioning keeps longer days on your feet comfortable.",
            features: "Soft cushioning · Airy mesh · Stability",
            matches: ["Trail-ready grip", "Cushioned comfort"],
            reviews: ["“So comfortable straight out of the box.”", "“Feels light, even on a longer trail.”", "“The cushioning makes a difference.”"],
            imageTint: Color(red: 0.87, green: 0.90, blue: 0.85)
        ),
        ShoppingProduct(
            id: "sample-salomon-xt6-sand", brand: "Salomon", title: "XT-6 Shoes — Sand",
            price: "$110", originalPrice: "$180", rating: "4.6", ratingCount: "620",
            summary: "A supportive everyday trail shoe\nwith a clean, versatile finish.",
            description: "A versatile trail-inspired shoe with a secure lacing system and a supportive sole. Breathable materials balance comfort with a structured, everyday fit.",
            features: "Secure lacing · Support · Breathability",
            matches: ["Versatile styling", "Supportive fit"],
            reviews: ["“Easy to wear all day, on or off the trail.”", "“A secure fit without feeling too tight.”", "“Love the simple color and sturdy feel.”"],
            imageTint: Color(red: 0.92, green: 0.89, blue: 0.83)
        )
    ]
}
