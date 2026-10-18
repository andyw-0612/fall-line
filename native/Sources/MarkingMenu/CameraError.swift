import Foundation

enum CameraError: LocalizedError {
    case unavailable, configuration, permission
    var errorDescription: String? {
        switch self {
        case .unavailable: "No Desk View camera is available. Choose Set up Desk View to open Apple's setup, or connect supported hardware."
        case .configuration: "The camera could not start. Close other camera apps and try again."
        case .permission: "Camera access is disabled. Allow Marking Menu in System Settings → Privacy & Security → Camera."
        }
    }
}
