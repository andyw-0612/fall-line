import Foundation

enum InputMode: String, CaseIterable, Identifiable {
    case mouse = "Mouse", trackpad = "Trackpad", finger = "Finger"
    var id: String { rawValue }
}
