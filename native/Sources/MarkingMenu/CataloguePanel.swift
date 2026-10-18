import SwiftUI

struct CataloguePanel: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: CatalogueSession
    @AppStorage("slowModeOverlayOpacity") private var slowModeOverlayOpacity = 60.0
    @State private var catalogueQuery = ""
    @State private var apiKey = ""
    @State private var credentialMessage = ""
    var body: some View {
        TabView {
            settingsTab
            tasteTab
            catalogueTab
            savedTab
            journeyTab
        }
        .frame(width: 700, height: 560)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Clear history", systemImage: "arrow.counterclockwise", action: clearHistory)
                Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }.padding(16)
        }
        .onDisappear { session.persist() }
    }

    private var settingsTab: some View {
        Form {
            Text(session.state.context).font(.headline)
            Picker("Recommendations", selection: $session.state.mode) {
                Text("Gemini AI").tag("ai"); Text("Local vectors + text").tag("local")
            }
            Picker("Shoes", selection: $session.state.gender) {
                Text("All").tag("all"); Text("Men").tag("men"); Text("Women").tag("women")
            }
            TextField("Maximum price (optional)", value: $session.state.maxPrice, format: .number)
            LabeledContent("Slow-mode overlay opacity") {
                HStack(spacing: 12) {
                    Slider(value: $slowModeOverlayOpacity, in: 0...100) {
                        Text("Slow-mode overlay opacity")
                    }
                    .labelsHidden()
                    .frame(width: 200)
                    .accessibilityValue("\(Int(slowModeOverlayOpacity.rounded())) percent")
                    Text("\(Int(slowModeOverlayOpacity.rounded()))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
            Text("Filters apply to future recommendation requests. Already queued shoes stay in order.")
                .foregroundStyle(.secondary)
            Text("\(session.records.count) shoes · \(session.state.queue.count) ready · \(session.state.pending.count + (session.loading ? 1 : 0)) requests waiting")
            if let error = session.error {
                Text(error).foregroundStyle(.red)
                HStack { Button("Retry", action: session.retry); Button("Use local recommendations", action: session.useLocal) }
            }
            SecureField("Gemini API key (optional override)", text: $apiKey)
            HStack {
                Button("Save key in Keychain") {
                    do { try CatalogueCredential.save(apiKey); apiKey = ""; credentialMessage = "Key saved securely." }
                    catch { credentialMessage = "Could not save the key: \(error.localizedDescription)" }
                }.disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text(credentialMessage).font(.caption)
            }
            Text("AI uses the catalogue’s existing Gemini configuration. Local mode works without a key. Listings are snapshots; check current availability and price with the merchant.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
    }

    private var tasteTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Taste profile").font(.title2)
                Text("The profile updates when a queued request finishes. Feedback remains chronological; newer reactions can change earlier preferences.")
                ForEach(session.state.profile.keys.sorted(), id: \.self) { aspect in
                    VStack(alignment: .leading) {
                        HStack { Text(aspect.capitalized).bold(); Spacer(); Button("Clear") { session.clear(aspect) } }
                        Text(session.state.profile[aspect] ?? "")
                    }
                }
                Text(session.state.chronology).foregroundStyle(.secondary)
                HStack { Button("Undo feedback", action: session.undo); Button("Clear all feedback") { session.clear() } }
                Divider()
                if let product = session.currentProduct {
                    Text("Adjust feedback for \(product.title)").font(.headline)
                    ForEach(["color", "shape", "style", "price", "brand", "type", "material", "quality", "performance"], id: \.self) { aspect in
                        HStack {
                            Text(aspect.capitalized).frame(width: 100, alignment: .leading)
                            Button("Like") { session.rate(aspect, value: 1) }
                            Button("Okay") { session.rate(aspect, value: 0) }
                            Button(aspect == "price" ? "Too expensive" : "Dislike") { session.rate(aspect, value: -1, reason: aspect == "price" ? "too_expensive" : nil) }
                            if aspect == "price" { Button("Too cheap") { session.rate(aspect, value: -1, reason: "too_cheap") } }
                            Button("Clear") { session.rate(aspect, value: nil) }
                        }.font(.caption)
                    }
                    Divider()
                }
                Text("Feedback history (\(session.state.events.count))").font(.headline)
                ForEach(session.state.events.reversed(), id: \.sequence) { event in
                            Text(feedbackDescription(event))
                        .font(.callout)
                }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }.tabItem { Label("Taste", systemImage: "sparkles") }
    }

    private var catalogueTab: some View {
        VStack {
            TextField("Search all 450 shoes", text: $catalogueQuery).textFieldStyle(.roundedBorder).padding()
            List {
                ForEach(session.records.filter { catalogueQuery.isEmpty || $0.title.localizedCaseInsensitiveContains(catalogueQuery) }, id: \.id) { record in
                    HStack {
                        VStack(alignment: .leading) { Text(record.title); Text(record.price_display).foregroundStyle(.secondary) }
                        Spacer()
                        Button("Explore") { session.visit(record.id); dismiss() }
                        Button(session.state.saved.contains(record.id) ? "Unsave" : "Save") { session.toggleSaved(record.id) }
                    }.padding(.vertical, 6)
                }
            }
        }.tabItem { Label("Catalogue", systemImage: "square.grid.2x2") }
    }

    private var savedTab: some View {
        List {
            ForEach(session.records.filter { session.state.saved.contains($0.id) }, id: \.id) { record in
                HStack {
                    VStack(alignment: .leading) { Text(record.title); Text(record.price_display).foregroundStyle(.secondary) }
                    Spacer()
                    if let url = record.product_url.flatMap(URL.init(string:)) { Link("View listing", destination: url) }
                    Button("Remove") { session.toggleSaved(record.id) }
                }.padding(.vertical, 8)
            }
            if session.state.saved.isEmpty { Text("Save a shoe with the heart on its product card.").foregroundStyle(.secondary) }
        }.tabItem { Label("Saved", systemImage: "heart") }
    }

    private var journeyTab: some View {
        List {
            Section("Visited shoes") {
            ForEach(Array(session.state.history.enumerated()), id: \.offset) { index, pick in
                Button { session.visit(pick.id); dismiss() } label: {
                    HStack { Text(session.records.first { $0.id == pick.id }?.title ?? pick.id); Spacer(); if index == session.state.cursor { Image(systemName: "checkmark") } }
                }.buttonStyle(.plain)
            }
            }
            Section("Up next · kept in recommendation order") {
                ForEach(session.state.queue) { pick in
                    VStack(alignment: .leading) {
                        Text(session.records.first { $0.id == pick.id }?.title ?? pick.id)
                        Text(pick.reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.tabItem { Label("Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
    }

    private func feedbackDescription(_ event: TasteEvent) -> String {
        guard event.type == "rating" else {
            return "\(event.sequence). \(event.type.replacingOccurrences(of: "_", with: " "))"
        }
        let reaction: String
        switch event.value {
        case 1: reaction = "Liked "
        case 0: reaction = "Okay with "
        case nil: reaction = "Cleared "
        default: reaction = "Disliked "
        }
        let reason = event.reason.map { " · " + $0.replacingOccurrences(of: "_", with: " ") } ?? ""
        return "\(event.sequence). " + reaction + (event.aspect ?? "") + reason
    }

    private func clearHistory() {
        session.clearHistory()
        dismiss()
    }

}
