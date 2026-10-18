import SwiftUI

struct ProductDetailCard: View {
    enum Kind { case brand, rating, review, matches, description }
    var kind: Kind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reviewIndex = 0
    var product = ShoppingProduct.samples[0]

    var body: some View {
        Group {
            switch kind {
            case .brand:
                Text(product.brand)
                    .font(StartupStyle.headingFont(size: 52))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: brandWidth - 80)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
                    .frame(minHeight: 112)
            case .rating:
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.32))
                    Text(product.rating == "—" ? "Unrated" : product.rating).font(StartupStyle.headingFont(size: 42))
                    Text(product.rating == "—" ? "" : "(\(product.ratingCount) ratings)")
                        .font(.system(size: 24))
                        .foregroundStyle(.black.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(product.rating) out of 5 stars, \(product.ratingCount) ratings")
            case .review:
                VStack(alignment: .leading, spacing: 20) {
                    Text("What Buyers Say")
                        .font(StartupStyle.headingFont(size: 32))
                        .frame(maxWidth: .infinity)
                    Text(product.reviews.isEmpty ? "No buyer comments available." : product.reviews[reviewIndex % product.reviews.count])
                        .contentTransition(.opacity)
                        .font(.system(size: 20))
                        .foregroundStyle(.black.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                        .help(product.reviews.isEmpty ? "" : product.reviews[reviewIndex % product.reviews.count])
                        .frame(minHeight: reviewHeight, alignment: .topLeading)
                    HStack(spacing: 8) {
                        
                        Text(product.reviewLabel).font(.system(size: 12)).foregroundStyle(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(0..<product.reviews.count, id: \.self) { index in
                                Circle().fill(.black.opacity(index == reviewIndex ? 0.85 : 0.25))
                                    .frame(width: 7, height: 7)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Quote \(reviewIndex + 1) of \(product.reviews.count)")
                        .accessibilityHidden(product.reviews.isEmpty)
                    }
                }
                .padding(32)
                .frame(width: 366)
                .task(id: product.reviews, cycleReviews)
            case .matches:
                VStack(spacing: 10) {
                    Text(product.matchStatus.capitalized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.5))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.black.opacity(0.08), in: .capsule)
                    Text("Matches").font(StartupStyle.headingFont(size: 32))
                    VStack(alignment: .leading, spacing: 8) {
                        if product.matches.isEmpty { Text("No confirmed intent matches").font(.system(size: 18)) }
                        ForEach(product.matches, id: \.self) { match in
                            Text(match).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.system(size: 21))
                    .foregroundStyle(Color(red: 0.37, green: 0.51, blue: 0.45))
                    Text(product.matchReason).fixedSize(horizontal: false, vertical: true)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.35))
                        .padding(.top, 18)
                }
                .padding(30)
                .frame(width: 366)
            case .description:
                VStack(alignment: .leading, spacing: 14) {
                    Text("Description")
                        .font(StartupStyle.headingFont(size: 32))
                        .frame(maxWidth: .infinity)
                    Text(product.description)
                        .font(.system(size: 17))
                        .foregroundStyle(.black.opacity(0.56))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(product.description)
                    Text(product.features)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.4))
                }
                .padding(32)
                .frame(width: 420, alignment: .topLeading)
            }
        }
        .foregroundStyle(.black)
    }

    // Text sizes stay capped; containers grow to fit the content instead.
    private var brandWidth: CGFloat {
        let width = (product.brand as NSString).size(withAttributes: [.font: StartupStyle.headingNSFont(size: 52)]).width
        return min(640, max(240, ceil(width) + 80))
    }

    private var reviewHeight: CGFloat {
        product.reviews.map { quote in
            (quote as NSString).boundingRect(with: CGSize(width: 302, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: NSFont.systemFont(ofSize: 20)]).height.rounded(.up)
        }.max() ?? 24
    }

    private func cycleReviews() async {
        reviewIndex = 0
        guard product.reviews.count > 1 else { return }
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(4)) }
            catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                reviewIndex = (reviewIndex + 1) % product.reviews.count
            }
        }
    }

}
