import AppKit
import CoreText

@MainActor enum MenuStyle {
    static let font: NSFont = {
        if let url = Bundle.main.url(forResource: "Outfit", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: "Outfit-Regular",
            kCTFontVariationAttribute: [NSNumber(value: 0x77676874): NSNumber(value: 600)]
        ] as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, 22, nil) as NSFont
    }()
}
