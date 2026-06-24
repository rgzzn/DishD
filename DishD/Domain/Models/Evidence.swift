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

    /// Conservative character budget for the evidence text fed to the on-device model.
    /// Apple's `SystemLanguageModel` has a small context window; an unbounded prompt
    /// (e.g. long OCR + transcript + caption, or a full web article) overflows it and
    /// makes generation fail. Typed evidence (title/ingredient/instruction/metadata) is
    /// prioritized so the most recipe-relevant text always survives the budget.
    static let promptCharacterBudget = 12_000

    var promptText: String {
        promptText(maxCharacters: Self.promptCharacterBudget)
    }

    /// Renders evidence within a character budget, keeping the highest-signal items.
    func promptText(maxCharacters: Int) -> String {
        let ordered = items.enumerated()
            .sorted { lhs, rhs in
                let lr = lhs.element.kind.promptPriority
                let rr = rhs.element.kind.promptPriority
                return lr != rr ? lr < rr : lhs.offset < rhs.offset
            }
            .map(\.element)

        var remaining = maxCharacters
        var lines: [String] = []
        for item in ordered where remaining > 0 {
            let prefix = "[\(item.reference)] [\(item.kind.rawValue)] "
            let budgetForBody = remaining - prefix.count
            guard budgetForBody > 0 else { break }
            let body = item.text.count <= budgetForBody
                ? item.text
                : String(item.text.prefix(budgetForBody))
            guard !body.isEmpty else { continue }
            let line = prefix + body
            lines.append(line)
            remaining -= line.count + 1
        }
        return lines.joined(separator: "\n")
    }

    var references: Set<String> {
        Set(items.map(\.reference))
    }
}

private extension EvidenceKind {
    /// Lower rank = kept first when the prompt budget is tight.
    var promptPriority: Int {
        switch self {
        case .title: return 0
        case .ingredient: return 1
        case .instruction: return 2
        case .metadata: return 3
        case .bodyText: return 4
        }
    }
}
