import AppKit
import Testing
import MarkingCore
@testable import MarkingMenu

private actor TestRanker {
    var requests: [CatalogueJob] = []
    var continuations: [CheckedContinuation<CatalogueResponse, Error>] = []
    func request(_ job: CatalogueJob) async throws -> CatalogueResponse {
        requests.append(job)
        return try await withCheckedThrowingContinuation { continuations.append($0) }
    }
    func resolve(_ ids: [String]) {
        continuations.removeFirst().resume(returning: CatalogueResponse(recommendations: ids.map {
            CataloguePick(id: $0, reason: "Test", intent_match: .init(status: "partial", reason: "Test intent", criteria: ["Blue"]))
        }, profile: ["color": "Blue"], chronology_note: "Test"))
    }
    func fail() { continuations.removeFirst().resume(throwing: CocoaError(.fileReadUnknown)) }
}

@MainActor struct CatalogueSessionTests {
    private func records() throws -> [CatalogueRecord] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalogue = root.appendingPathComponent("Build/Marking Menu.app/Contents/Resources/Catalogue/data/enriched-450/catalogue.json")
        return try JSONDecoder().decode(CatalogueDocument.self, from: Data(contentsOf: catalogue)).products
    }
    private func make(_ ranker: TestRanker) throws -> CatalogueSession {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let session = CatalogueSession(persistenceURL: url, recommend: { try await ranker.request($0) })
        session.records = try records()
        return session
    }
    private func wait(_ condition: () async -> Bool) async throws {
        for _ in 0..<100 { if await condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        Issue.record("Session condition timed out")
    }
    private func entry(_ leaf: String, id: Int = 1) throws -> HistoryEntry {
        func search(_ node: MenuNode, _ path: [MenuNode]) -> [MenuNode]? {
            if node.id == leaf { return path + [node] }
            return node.children.compactMap { search($0, path + [node]) }.first
        }
        return HistoryEntry(id: id, path: try #require(search(.root, [])))
    }
    @Test func all450RecordsAndImagesAreUsable() throws {
        let products = try records()
        #expect(products.count == 450)
        #expect(Set(products.map(\.id)).count == 450)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Build/Marking Menu.app/Contents/Resources/Catalogue/data/images")
        for product in products {
            let url = root.appendingPathComponent(URL(fileURLWithPath: product.image_path).lastPathComponent)
            #expect(NSImage(contentsOf: url) != nil, "Every real shoe image must decode")
            let whiteURL = root.deletingLastPathComponent().appendingPathComponent("images-white/" + product.id + ".png")
            #expect(NSImage(contentsOf: whiteURL) != nil, "Every shoe must have its white-background image")
        }
    }
    @Test func orderedQueueFreezesFeedbackAndExcludesSeenAndBufferedShoes() async throws {
        let ranker = TestRanker(), session = try make(ranker)
        let ids = session.records.prefix(20).map(\.id)
        session.search("Blue shoes")
        try await wait { await ranker.requests.count == 1 }
        #expect(await ranker.requests[0].body.count == 5)
        await ranker.resolve(Array(ids.prefix(5)))
        try await wait { session.currentPick != nil }
        #expect(session.currentPick?.id == ids[0]); #expect(session.state.queue.count == 4)
        session.feedback(try entry("aesthetic-color-like"))
        session.next()
        try await wait { await ranker.requests.count == 2 }
        #expect(session.currentPick?.id == ids[1])
        #expect(await ranker.requests[1].body.count == 2)
        #expect(await ranker.requests[1].body.events.count == 1)
        #expect(Set(await ranker.requests[1].body.excluded_ids) == Set(ids.prefix(5)))
        session.feedback(try entry("price-too-cheap", id: 2))
        session.next()
        #expect(session.state.pending.count == 1)
        #expect(session.state.pending[0].body.events.last?.reason == "too_cheap")
        session.clear("color")
        await ranker.resolve(Array(ids[5..<7]))
        try await wait { await ranker.requests.count == 3 }
        #expect(await ranker.requests[2].body.count == 2)
        #expect(await ranker.requests[2].body.events.count == 2)
        #expect(Set(await ranker.requests[2].body.excluded_ids) == Set(ids.prefix(7)))
        await ranker.resolve(Array(ids[7..<9]))
        try await wait { !session.loading }
        #expect(session.state.queue.map(\.id) == Array(ids[3..<9]))
    }
    @Test func failureRetryAndUndoDoNotLoseFrozenSubmission() async throws {
        let ranker = TestRanker(), session = try make(ranker)
        let ids = session.records.prefix(11).map(\.id)
        session.search("Running shoes")
        try await wait { await ranker.requests.count == 1 }
        await ranker.fail()
        try await wait { session.error != nil }
        #expect(session.state.pending.count == 1)
        session.retry()
        try await wait { await ranker.requests.count == 2 }
        #expect(await ranker.requests[0].body.variant == ranker.requests[1].body.variant)
        await ranker.resolve(ids)
        try await wait { session.currentPick != nil }
        session.feedback(try entry("product-brand-dislike"))
        #expect(session.state.events.last?.aspect == "brand")
        session.undoGesture(1); #expect(session.state.events.isEmpty)
        session.feedback(try entry("aesthetic-color-like", id: 2))
        session.clear("color")
        session.feedback(try entry("aesthetic-color-like", id: 3))
        #expect(session.state.events.count == 3)
        session.undo(); #expect(session.state.events.count == 2)
        let decoded = try JSONDecoder().decode(CatalogueState.self, from: Data(contentsOf: session.sessionURL))
        #expect(decoded.events.count == 2); #expect(decoded.history.count == 1)
        #expect(decoded.undoEvents?.isEmpty == false)
        try? FileManager.default.removeItem(at: session.sessionURL)
    }
    @Test func restartResumesInterruptedInitialRequestAndKeepsSavedShoes() async throws {
        let ranker = TestRanker(), session = try make(ranker)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Build/Marking Menu.app/Contents/Resources/Catalogue")
        let id = session.records[0].id
        session.state.context = "Blue walking shoes"; session.state.saved = [id]
        session.enqueue(count: 11)
        session.state.active = session.state.pending.removeFirst()
        session.persist()
        let restored = CatalogueSession(persistenceURL: session.sessionURL, recommend: { try await ranker.request($0) })
        await restored.load(root: root)
        try await wait { await ranker.requests.count == 1 }
        #expect(restored.state.saved.contains(id)); #expect(restored.currentPick == nil)
        #expect(await ranker.requests[0].body.initial_context == "Blue walking shoes")
        await ranker.resolve([id])
        try await wait { restored.currentPick != nil }
        #expect(restored.currentPick?.id == id)
        #expect(restored.state.active == nil)
        #expect(restored.state.seen.contains(id))
        try? FileManager.default.removeItem(at: session.sessionURL)
    }
    @Test func feedbackOnEarlierShoeBranchesAndSubmitsUpdatedFeedback() async throws {
        let ranker = TestRanker(), session = try make(ranker)
        let ids = session.records.prefix(11).map(\.id)
        session.search("Shoes")
        try await wait { await ranker.requests.count == 1 }
        await ranker.resolve(ids)
        try await wait { session.currentPick != nil }
        session.next()
        try await wait { await ranker.requests.count == 2 }
        session.previous()
        session.rate("brand", value: -1)
        #expect(session.state.history.count == 1)
        session.next()
        #expect(session.state.pending.count == 1)
        #expect(session.state.pending[0].body.events.last?.aspect == "brand")
        await ranker.resolve([])
        try await wait { await ranker.requests.count == 3 }
        await ranker.resolve([])
        try await wait { !session.loading }
        #expect(session.state.history.last?.id == ids[2])
        #expect(session.state.seen.contains(ids[1]))
        try? FileManager.default.removeItem(at: session.sessionURL)
    }
    @Test func clearingHistoryPersistsFreshStateAndIgnoresLateRecommendations() async throws {
        let ranker = TestRanker(), session = try make(ranker)
        let ids = session.records.prefix(20).map(\.id)
        session.search("Old search")
        try await wait { await ranker.requests.count == 1 }
        await ranker.resolve(Array(ids.prefix(11)))
        try await wait { session.currentPick != nil }
        session.rate("color", value: 1)
        session.toggleSaved(ids[0])
        session.next()
        try await wait { await ranker.requests.count == 2 }
        let resetID = session.historyResetID
        session.clearHistory()
        #expect(session.historyResetID != resetID)
        #expect(session.currentPick == nil && session.state.context.isEmpty)
        #expect(session.state.events.isEmpty && session.state.history.isEmpty && session.state.seen.isEmpty)
        #expect(session.state.queue.isEmpty && session.state.pending.isEmpty && session.state.active == nil)
        #expect(session.state.profile.isEmpty && session.state.chronology.isEmpty)
        #expect(session.state.undoEvents?.isEmpty == true)
        #expect(session.state.sequence == 0 && !session.loading && !session.isWaiting)
        #expect(session.state.saved == [ids[0]])
        let persisted = try JSONDecoder().decode(CatalogueState.self, from: Data(contentsOf: session.sessionURL))
        #expect(persisted.history.isEmpty && persisted.events.isEmpty && persisted.queue.isEmpty)
        session.search("Fresh boots")
        try await wait { await ranker.requests.count == 3 }
        #expect(await ranker.requests[2].body.events.isEmpty)
        #expect(await ranker.requests[2].body.excluded_ids.isEmpty)
        await ranker.resolve([ids[11]]) // The older, invalidated request finishes first.
        await ranker.resolve([ids[15]])
        try await wait { !session.loading }
        #expect(session.state.context == "Fresh boots")
        #expect(session.state.history.map(\.id) == [ids[15]])
        #expect(session.state.queue.isEmpty)
        try? FileManager.default.removeItem(at: session.sessionURL)
    }
    @Test func everyGestureMapsToItsOwnCanonicalAspect() throws {
        func leaves(_ node: MenuNode) -> [String] { node.isLeaf ? [node.id] : node.children.flatMap(leaves) }
        for leaf in leaves(.root) {
            let entry = try entry(leaf)
            #expect(entry.aspect != nil)
            #expect(entry.aspect != "shape")
        }
    }
}
