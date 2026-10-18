import MarkingCore

struct HistoryEntry: Identifiable {
    let id: Int
    let path: [MenuNode]
    var aspect: String? {
        let names = path.map { $0.name.lowercased() }
        return ["price", "brand", "type", "color", "style", "material", "quality", "performance"].first { names.contains($0) }
    }
    var title: String { path.map(\.name).joined(separator: " → ") }
    var feedbackMessage: String {
        let liked = path.contains { $0.name == "I Like It" }
        let attribute = path.last { !$0.isLeaf && $0.name != "I Like It" && $0.name != "I Don't Like It" }?.name.lowercased() ?? "product"
        let subject = attribute == "type" ? "product type" : attribute
        let reason: String = switch path.last?.id {
        case "price-too-expensive": " (too expensive)"
        case "price-too-cheap": " (too cheap)"
        default: ""
        }
        return "You \(liked ? "liked" : "did not like") the \(subject)\(reason)"
    }
}
