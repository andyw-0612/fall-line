import Foundation

/// Bounded, local diagnostics of gestures on this canvas only. No camera images,
/// system-wide pointer movement, or network traffic are recorded.
actor GestureTraceStore {
    private let directory = URL.applicationSupportDirectory.appending(path: "Marking Menu")
    private var recent: [GestureTrace] = []
    private var loaded = false

    func record(_ trace: GestureTrace) {
        let url = directory.appending(path: "RecentGestures.json")
        do {
            if !loaded {
                loaded = true
                if FileManager.default.fileExists(atPath: url.path) {
                    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
                    do { recent = try decoder.decode([GestureTrace].self, from: Data(contentsOf: url)) }
                    catch { NSLog("Starting fresh menu gesture diagnostics: %@", error.localizedDescription) }
                }
            }
            recent.append(trace)
            recent = Array(recent.sorted { $0.date < $1.date }.suffix(20))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(recent).write(to: url, options: .atomic)
        } catch { NSLog("Menu gesture diagnostics: %@", error.localizedDescription) }
    }
}
