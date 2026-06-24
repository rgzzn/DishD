import Foundation

struct EvidenceItem: Identifiable, Sendable, Codable, Equatable {
    let id: UUID
    let kind: EvidenceKind
    let text: String
    let confidence: Double
    let provenance: EvidenceProvenance

    init(
        id: UUID = UUID(),
        kind: EvidenceKind,
        text: String,
        confidence: Double = 1,
        provenance: EvidenceProvenance
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.confidence = confidence
        self.provenance = provenance
    }

    var reference: String { id.uuidString }
}

enum EvidenceKind: String, Sendable, Codable {
    case title
    case ingredient
    case instruction
    case metadata
    case bodyText
}

struct EvidenceProvenance: Sendable, Codable, Equatable {
    let source: String
    let location: String?
}

struct RecipeEvidenceBundle: Sendable {
    let items: [EvidenceItem]
    let source: RecipeSourceDraft

    var promptText: String {
        items.map { item in
            "[\(item.reference)] [\(item.kind.rawValue)] \(item.text)"
        }
        .joined(separator: "\n")
    }

    var references: Set<String> {
        Set(items.map(\.reference))
    }
}
