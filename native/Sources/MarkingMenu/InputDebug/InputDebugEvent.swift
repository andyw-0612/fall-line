import Foundation

struct InputDebugEvent: Identifiable {
    let id = UUID()
    let time: Date
    let message: String
}
