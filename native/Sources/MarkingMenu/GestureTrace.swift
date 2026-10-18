import Foundation

struct GestureTrace: Codable, Sendable {
    let date: Date
    let input: String
    let releaseMode: String
    let termination: String
    let samples: [GestureSample]
    let selectedPath: [String]?
}
