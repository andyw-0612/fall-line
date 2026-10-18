import SwiftUI

struct ProductCardSizePreferenceKey: PreferenceKey {
    static let defaultValue: [ProductCardRole: CGSize] = [:]
    static func reduce(value: inout [ProductCardRole: CGSize], nextValue: () -> [ProductCardRole: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func measuringProductCard(_ role: ProductCardRole) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: ProductCardSizePreferenceKey.self, value: [role: geometry.size])
            }
        }
    }
}
