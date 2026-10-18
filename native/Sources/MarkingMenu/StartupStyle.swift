import SwiftUI
import CoreText

@MainActor enum StartupStyle {
    // Sampled from the supplied swatch, whose embedded profile is Display P3.
    static let background = Color(.displayP3, red: 202 / 255, green: 215 / 255, blue: 213 / 255)
    static let secondary = Color(red: 0.34, green: 0.35, blue: 0.35)

    private static let registerFont: Void = {
        if let url = Bundle.main.url(forResource: "Outfit", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func headingFont(size: CGFloat) -> Font {
        Font(headingNSFont(size: size))
    }

    static func headingNSFont(size: CGFloat) -> NSFont {
        _ = registerFont
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: "Outfit-Regular",
            kCTFontVariationAttribute: [NSNumber(value: 0x77676874): NSNumber(value: 700)]
        ] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil) as NSFont
    }
}
