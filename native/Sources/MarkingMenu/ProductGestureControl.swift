import SwiftUI

struct ProductGestureControl: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ProductControlBoundsKey.self,
                    // Include the full bobbing range so controls remain clickable.
                    value: [geometry.frame(in: .named("productGestureSurface")).insetBy(dx: -5, dy: -14)]
                )
            }
        }
    }
}
