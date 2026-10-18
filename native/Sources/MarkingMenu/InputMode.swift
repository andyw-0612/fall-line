import Foundation

enum InputMode: String, CaseIterable, Identifiable {
    case mouse = "Mouse", trackpad = "Trackpad"
    var id: String { rawValue }
}
