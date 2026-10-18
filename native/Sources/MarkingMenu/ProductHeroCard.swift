import SwiftUI

struct ProductHeroCard: View {
    var product = ShoppingProduct.samples[0]
    var saved = false
    var onSave: () -> Void = {}
    @State private var showDetails = false
    @State private var imageIndex = 0
    private let images = ["photo", "photo.on.rectangle", "photo.stack"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(product.imageTint)
                if let url = product.imageURL, let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFit().padding(12).accessibilityLabel(product.title)
                } else {
                    Image(systemName: "photo").font(.system(size: 80)).foregroundStyle(.gray)
                }
            }
            .frame(height: 286)
            .overlay(alignment: .topTrailing) {
                Button(action: onSave) {
                    Label(saved ? "Remove from saved products" : "Save product", systemImage: saved ? "heart.fill" : "heart")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(saved ? Color(red: 0.90, green: 0.44, blue: 0.49) : .gray)
                        .frame(width: 46, height: 46)
                        .background(.white, in: .circle)
                        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
                }
                .buttonStyle(.plain)
                .modifier(ProductGestureControl())
                .padding(24)
            }


            Text(product.title)
                .font(StartupStyle.headingFont(size: 30))
                .fixedSize(horizontal: false, vertical: true)
                .help(product.title)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(product.price).font(StartupStyle.headingFont(size: 30))
                if !product.originalPrice.isEmpty { Text(product.originalPrice)
                    .font(.system(size: 28))
                    .strikethrough()
                    .foregroundStyle(.black.opacity(0.3))
                    .accessibilityLabel("Originally \(product.originalPrice)") }
            }
            Text(product.summary)
                .font(.system(size: 17))
                .foregroundStyle(.black.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Details") { showDetails = true }
                Spacer()
                if let url = product.productURL { Link("View listing ↗", destination: url) }
            }.font(.system(size: 15)).modifier(ProductGestureControl())
        }
        .foregroundStyle(.black)
        .padding(28)
        .frame(width: 440, alignment: .leading)
        .sheet(isPresented: $showDetails) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(product.title).font(.title2)
                    Text(product.price).font(.title)
                    Text(product.brand).font(.headline)
                    Text(product.rating == "—" ? "Ratings unavailable" : "\(product.rating) stars · \(product.ratingCount) ratings")
                    Text(product.summary).foregroundStyle(.secondary)
                    Text(product.fullDescription ?? product.description)
                    Text("Features are inferred from images. Prices and ratings are listing snapshots.").foregroundStyle(.secondary)
                    Text(product.matchReason)
                    Text(product.reviewLabel).font(.headline)
                    ForEach(product.reviews, id: \.self) { Text($0) }
                    if let url = product.productURL { Link("View merchant listing", destination: url) }
                    Button("Done") { showDetails = false }
                }.padding(32)
            }.frame(width: 540, height: 500)
        }
    }

}
