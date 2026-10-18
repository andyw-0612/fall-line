import SwiftUI

struct CatalogueRecord: Decodable, Sendable {
    struct Brand: Decodable, Sendable { var name: String? }
    struct Ratings: Decodable, Sendable { var value: Double?; var count: Int? }
    struct Feedback: Decodable, Sendable {
        struct Review: Decodable, Sendable { var text: String }
        var label: String?; var reviews: [Review]
    }
    let id: String; let title: String; let price: Double
    let price_display: String; let merchant: String?; let product_url: String?; let image_path: String
    let descriptions: [String: String]; let brand: Brand?; let ratings: Ratings?; let buyer_feedback: Feedback?
}
struct CatalogueDocument: Decodable, Sendable { var products: [CatalogueRecord] }
struct TasteEvent: Codable, Sendable {
    var sequence: Int; var time: String; var type: String = "rating"
    var productId: String?; var aspect: String?; var value: Int?; var reason: String?
}
struct CataloguePick: Codable, Sendable, Identifiable {
    struct Match: Codable, Sendable { var status: String; var reason: String; var criteria: [String] }
    var id: String; var reason: String; var intent_match: Match?
}
struct CatalogueRequest: Codable, Sendable {
    var initial_context: String; var events: [TasteEvent]; var excluded_ids: [String]
    var gender_filter: String; var max_price: Double?; var variant: Int; var count: Int
}
struct CatalogueResponse: Decodable, Sendable {
    var recommendations: [CataloguePick]; var profile: [String: String]; var chronology_note: String?
}
struct CatalogueJob: Codable, Sendable { var body: CatalogueRequest; var mode: String }
struct CatalogueState: Codable {
    var datasetID: String?
    var context = ""; var mode = "ai"; var gender = "all"; var maxPrice: Double?
    var events: [TasteEvent] = []; var sequence = 0
    var history: [CataloguePick] = []; var cursor = 0; var queue: [CataloguePick] = []
    var seen: Set<String> = []; var saved: Set<String> = []
    var pending: [CatalogueJob] = []; var active: CatalogueJob?
    var profile: [String: String] = [:]; var chronology = ""
    var undoEvents: [[TasteEvent]]? = []
}

enum CatalogueRuntime {
    static var root: URL { Bundle.main.resourceURL!.appendingPathComponent("Catalogue") }
    static var support: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Fall Line") }
    static func request(_ job: CatalogueJob) async throws -> CatalogueResponse {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            process.arguments = [root.appendingPathComponent("bridge.py").path]
            var environment = ProcessInfo.processInfo.environment
            if let key = CatalogueCredential.read(), !key.isEmpty { environment["GEMINI_API_KEY"] = key }
            environment["FALL_LINE_CACHE_DIR"] = support.appendingPathComponent("cache").path
            process.environment = environment
            let input = Pipe(), output = Pipe()
            process.standardInput = input; process.standardOutput = output
            // The adapter returns a sanitized JSON error; provider logs stay out of the UI.
            process.standardError = FileHandle.nullDevice
            struct Envelope: Encodable { var mode: String; var body: CatalogueRequest }
            let data = try JSONEncoder().encode(Envelope(mode: job.mode, body: job.body))
            try process.run()
            try input.fileHandleForWriting.write(contentsOf: data)
            try input.fileHandleForWriting.close()
            let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 180, execute: watchdog)
            let result = output.fileHandleForReading.readDataToEndOfFile()
            watchdog.cancel()
            process.waitUntilExit()
            struct Failure: Decodable { var error: String }
            if let failure = try? JSONDecoder().decode(Failure.self, from: result) {
                throw NSError(domain: "Catalogue", code: 1, userInfo: [NSLocalizedDescriptionKey: failure.error])
            }
            guard process.terminationStatus == 0 else { throw CocoaError(.executableRuntimeMismatch) }
            return try JSONDecoder().decode(CatalogueResponse.self, from: result)
        }.value
    }
}

@MainActor @Observable final class CatalogueSession {
    var state = CatalogueState()
    var records: [CatalogueRecord] = []
    var loading = false; var error: String?; var ready = false; var exhausted = false
    private var generation = UUID(); private var waiting = false
    private(set) var historyResetID = UUID()
    private var gestureEvents: [Int: Int] = [:]
    @ObservationIgnored private let recommend: @Sendable (CatalogueJob) async throws -> CatalogueResponse
    @ObservationIgnored private let persistenceURL: URL?
    init(persistenceURL: URL? = nil, recommend: @escaping @Sendable (CatalogueJob) async throws -> CatalogueResponse = CatalogueRuntime.request) {
        self.persistenceURL = persistenceURL; self.recommend = recommend
    }
    var isWaiting: Bool { waiting }
    var currentPick: CataloguePick? { state.history.indices.contains(state.cursor) ? state.history[state.cursor] : nil }
    var currentProduct: ShoppingProduct? { currentPick.flatMap(product) }
    var sessionURL: URL { persistenceURL ?? CatalogueRuntime.support.appendingPathComponent("session.json") }

    func load(root: URL = CatalogueRuntime.root) async {
        do {
            let url = root.appendingPathComponent("data/enriched-450/catalogue.json")
            records = try await Task.detached { try JSONDecoder().decode(CatalogueDocument.self, from: Data(contentsOf: url)).products }.value
            try FileManager.default.createDirectory(at: CatalogueRuntime.support, withIntermediateDirectories: true)
            if let data = try? Data(contentsOf: sessionURL), let saved = try? JSONDecoder().decode(CatalogueState.self, from: data) {
                state = saved
                if let active = state.active { state.pending.insert(active, at: 0); state.active = nil }
            }
            let manifest = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
            let identity = (try JSONSerialization.jsonObject(with: manifest) as? [String: Any])?["dataset_id"] as? String
            if let previous = state.datasetID, previous != identity {
                let saved = state.saved.intersection(records.map(\.id)); state = CatalogueState(); state.saved = saved
            }
            state.datasetID = identity
            waiting = currentPick == nil && !state.context.isEmpty
            ready = true
            pump()
        } catch { self.error = "Could not load the shoe catalogue: \(error.localizedDescription)" }
    }
    func product(_ pick: CataloguePick) -> ShoppingProduct? {
        guard let p = records.first(where: { $0.id == pick.id }) else { return nil }
        return ShoppingProduct(id: p.id, brand: p.brand?.name ?? "Brand not listed", title: p.title,
            price: p.price_display, originalPrice: "", rating: p.ratings?.value.map { String(format: "%.1f", $0) } ?? "—",
            ratingCount: p.ratings?.count.map(String.init) ?? "0", summary: p.merchant ?? "Catalogue listing",
            description: p.descriptions["style"] ?? "", features: "Image-inferred description",
            matches: pick.intent_match?.criteria ?? [], reviews: p.buyer_feedback?.reviews.map(\.text) ?? [], imageTint: .white,
            fullDescription: ["color", "shape", "style"].compactMap { key in p.descriptions[key].map { key.capitalized + ": " + $0 } }.joined(separator: "\n\n"),
            imageURL: CatalogueRuntime.root.appendingPathComponent("data/images-white/" + p.id + ".png"),
            productURL: p.product_url.flatMap(URL.init(string:)), reviewLabel: "Generated examples · not buyer testimony",
            matchStatus: pick.intent_match?.status ?? "unknown", matchReason: pick.intent_match?.reason ?? pick.reason)
    }
    func clearHistory() {
        resetSession()
        historyResetID = UUID()
        persist()
    }
    private func resetSession() {
        // Invalidate any in-flight result before clearing its session state.
        generation = UUID(); loading = false; error = nil; waiting = false; exhausted = false
        let previous = state
        state = CatalogueState()
        state.datasetID = previous.datasetID; state.saved = previous.saved
        state.mode = previous.mode; state.gender = previous.gender; state.maxPrice = previous.maxPrice
        gestureEvents = [:]
    }
    func search(_ query: String) {
        resetSession()
        waiting = true
        state.context = String(query.prefix(1000))
        // One product on screen, with four ready in the initial queue.
        enqueue(count: 5); pump()
    }
    func enqueue(count: Int) {
        state.pending.append(CatalogueJob(body: CatalogueRequest(initial_context: state.context, events: state.events,
            excluded_ids: Array(state.seen.union(state.queue.map(\.id))), gender_filter: state.gender,
            max_price: state.maxPrice, variant: Int.random(in: 0...Int(UInt32.max)), count: count), mode: state.mode))
        persist()
    }
    func next() {
        guard !waiting else { return }
        if state.cursor + 1 < state.history.count { state.cursor += 1; persist(); return }
        enqueue(count: 2)
        advance(); pump()
    }
    private func advance() {
        if !state.queue.isEmpty {
            let pick = state.queue.removeFirst(); state.history.append(pick); state.cursor = state.history.count - 1
            state.seen.insert(pick.id); waiting = false; persist()
        } else { waiting = true }
    }
    func visit(_ id: String) {
        guard records.contains(where: { $0.id == id }) else { return }
        if state.context.isEmpty { state.context = "Explore shoes" }
        if let index = state.history.firstIndex(where: { $0.id == id }) { state.cursor = index }
        else {
            if state.cursor + 1 < state.history.count { state.history = Array(state.history.prefix(state.cursor + 1)) }
            state.history.append(CataloguePick(id: id, reason: "Opened directly from the catalogue. No AI intent assessment has been made.", intent_match: nil))
            state.queue.removeAll { $0.id == id }; state.seen.insert(id); state.cursor = state.history.count - 1
        }
        waiting = false; persist()
    }
    func previous() { guard state.cursor > 0 else { return }; waiting = false; state.cursor -= 1; persist() }
    func pump() {
        guard !loading, error == nil, !state.pending.isEmpty else { return }
        loading = true
        var job = state.pending.removeFirst()
        job.body.excluded_ids = Array(Set(job.body.excluded_ids).union(state.seen).union(state.queue.map(\.id)))
        state.active = job; persist(); let token = generation
        Task {
            do {
                let response = try await recommend(job)
                guard token == generation else { return }
                let excluded = state.seen.union(state.queue.map(\.id))
                var unique = excluded
                state.queue += response.recommendations.filter { pick in records.contains(where: { $0.id == pick.id }) && unique.insert(pick.id).inserted }
                state.profile = response.profile; state.chronology = response.chronology_note ?? ""
                exhausted = state.queue.isEmpty && response.recommendations.isEmpty
                state.active = nil; loading = false
                if waiting, !state.queue.isEmpty { advance() }
                if exhausted { waiting = false }
                persist(); pump()
            } catch {
                guard token == generation else { return }
                state.pending.insert(job, at: 0); state.active = nil; loading = false
                self.error = error.localizedDescription; persist()
            }
        }
    }
    func retry() { error = nil; pump() }
    func useLocal() {
        state.mode = "local"
        for i in state.pending.indices { state.pending[i].mode = "local" }
        retry(); persist()
    }
    func feedback(_ entry: HistoryEntry) {
        guard currentPick != nil, let aspect = entry.aspect else { return }
        let value = entry.path.contains { $0.name == "I Like It" } ? 1 : -1
        let reason = entry.path.last?.id == "price-too-cheap" ? "too_cheap" : entry.path.last?.id == "price-too-expensive" ? "too_expensive" : nil
        if let sequence = rate(aspect, value: value, reason: reason) { gestureEvents[entry.id] = sequence }
    }
    @discardableResult func rate(_ aspect: String, value: Int?, reason: String? = nil) -> Int? {
        guard let id = currentPick?.id else { return nil }
        let sinceClear = state.events.lastIndex { $0.type == "clear_all" || ($0.type == "clear_aspect" && $0.aspect == aspect) }.map { $0 + 1 } ?? 0
        if let last = state.events.dropFirst(sinceClear).last(where: { $0.productId == id && $0.aspect == aspect }), last.value == value && last.reason == reason { return nil }
        guard state.events.count < 600 else { error = "This search has reached 600 feedback events. Start a new search to continue."; return nil }
        state.undoEvents = Array(((state.undoEvents ?? []) + [state.events]).suffix(30))
        state.sequence += 1
        state.events.append(TasteEvent(sequence: state.sequence, time: ISO8601DateFormatter().string(from: Date()), productId: id, aspect: aspect, value: value, reason: reason))
        branchHistory(); persist()
        return state.sequence
    }
    private func branchHistory() {
        if state.cursor + 1 < state.history.count { state.history = Array(state.history.prefix(state.cursor + 1)) }
    }
    func undoGesture(_ id: Int) {
        guard let sequence = gestureEvents.removeValue(forKey: id) else { return }
        state.events.removeAll { $0.sequence == sequence }
        if let snapshots = state.undoEvents { state.undoEvents = snapshots.map { $0.filter { $0.sequence != sequence } } }
        branchHistory(); persist()
    }
    func undo() { guard let previous = state.undoEvents?.popLast() else { return }; state.events = previous; branchHistory(); persist() }
    func clear(_ aspect: String? = nil) {
        state.undoEvents = Array(((state.undoEvents ?? []) + [state.events]).suffix(30)); state.sequence += 1
        guard state.events.count < 600 else { return }
        state.events.append(TasteEvent(sequence: state.sequence, time: ISO8601DateFormatter().string(from: Date()), type: aspect == nil ? "clear_all" : "clear_aspect", aspect: aspect))
        branchHistory(); persist()
    }
    func toggleSaved(_ id: String) { if !state.saved.insert(id).inserted { state.saved.remove(id) }; persist() }
    func persist() { if let data = try? JSONEncoder().encode(state) { try? data.write(to: sessionURL, options: .atomic) } }
}
