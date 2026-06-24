import Foundation

struct DeterministicTextRecipeParser: Sendable {
    private let units = [
        "g", "gr", "kg", "ml", "cl", "dl", "l", "tazza", "tazze", "cup", "cups",
        "cucchiaio", "cucchiai", "cucchiaino", "cucchiaini", "tbsp", "tsp",
        "spicchio", "spicchi", "fetta", "fette", "vasetto", "bicchiere"
    ]

    func parse(
        _ text: String,
        source: RecipeSourceDraft = .manual
    ) -> (draft: RecipeDraft, evidence: RecipeEvidenceBundle)? {
        let normalized = text
            .precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { cleanLine(String($0)) }

        guard let firstContent = lines.first(where: {
            !$0.isEmpty && !$0.hasPrefix("[")
        }) else {
            return nil
        }

        var evidence: [EvidenceItem] = [
            EvidenceItem(
                kind: .title,
                text: firstContent,
                provenance: .init(source: source.platform, location: "prima riga")
            )
        ]
        var ingredients: [IngredientDraft] = []
        var steps: [StepDraft] = []
        var mode: SectionMode = .unknown

        for line in lines.drop(while: { $0 != firstContent }).dropFirst() {
            guard !line.isEmpty else { continue }
            let lower = line.lowercased()
            if lower.range(
                of: #"^(?:per\s+)?\d+(?:[,.]\d+)?\s+(?:persone|porzioni)$"#,
                options: .regularExpression
            ) != nil {
                evidence.append(
                    EvidenceItem(
                        kind: .metadata,
                        text: line,
                        provenance: .init(source: source.platform, location: "testo")
                    )
                )
                continue
            }
            if lower.range(of: #"^(ingredienti|occorrente|per l.impasto|per la crema)\b"#, options: .regularExpression) != nil {
                mode = .ingredients
                continue
            }
            if lower.range(of: #"^(procedimento|preparazione|istruzioni|passaggi|metodo)\b"#, options: .regularExpression) != nil {
                mode = .steps
                continue
            }

            if mode == .ingredients || (mode == .unknown && looksLikeIngredient(line)) {
                let item = EvidenceItem(
                    kind: .ingredient,
                    text: line,
                    provenance: .init(source: source.platform, location: "testo")
                )
                evidence.append(item)
                ingredients.append(parseIngredient(line, evidenceID: item.reference))
                continue
            }

            if mode == .steps {
                let item = EvidenceItem(
                    kind: .instruction,
                    text: line,
                    provenance: .init(source: source.platform, location: "testo")
                )
                evidence.append(item)
                if looksLikeInstruction(line) || steps.isEmpty {
                    steps.append(
                        StepDraft(
                            instruction: removeListPrefix(line),
                            confidence: 0.76,
                            evidenceIDs: [item.reference]
                        )
                    )
                } else {
                    steps[steps.count - 1].instruction += " \(removeListPrefix(line))"
                    steps[steps.count - 1].evidenceIDs.append(item.reference)
                }
                continue
            }

            if looksLikeInstruction(line) {
                let item = EvidenceItem(
                    kind: .instruction,
                    text: line,
                    provenance: .init(source: source.platform, location: "testo")
                )
                evidence.append(item)
                steps.append(
                    StepDraft(
                        instruction: removeListPrefix(line),
                        confidence: 0.76,
                        evidenceIDs: [item.reference]
                    )
                )
            }
        }

        let servingsText = firstMatch(
            in: normalized,
            pattern: #"(?i)(?:per\s+|porzioni?\s*:?\s*|persone\s*:?\s*)(\d+(?:[,.]\d+)?)"#
        )
        let title = firstContent
            .replacingOccurrences(
                of: #"(?i)\s+(?:per\s+)?\d+\s*(?:porzioni|persone)?\s*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isRecipe = !ingredients.isEmpty || !steps.isEmpty
        guard isRecipe else { return nil }

        var unresolved: [UnresolvedFieldDraft] = []
        if ingredients.isEmpty {
            unresolved.append(.init(fieldName: "ingredients", message: "Ingredienti non riconosciuti nel testo."))
        }
        if steps.isEmpty {
            unresolved.append(.init(fieldName: "steps", message: "Procedimento non riconosciuto nel testo."))
        }
        if servingsText == nil {
            unresolved.append(.init(fieldName: "servings", message: "Porzioni non specificate."))
        }

        let draft = RecipeDraft(
            title: title.isEmpty ? "Ricetta importata" : title,
            servings: DecimalParser.parse(servingsText),
            servingsLabel: servingsText,
            ingredientSections: ingredients.isEmpty ? [] : [.init(ingredients: ingredients)],
            steps: steps,
            unresolved: unresolved,
            source: source,
            confidence: ingredients.isEmpty || steps.isEmpty ? 0.48 : 0.72,
            extractionMethod: .deterministicText
        )

        return (draft, RecipeEvidenceBundle(items: evidence, source: source))
    }

    private func looksLikeIngredient(_ line: String) -> Bool {
        let lower = removeListPrefix(line).lowercased()
        if lower.hasPrefix("q.b.") || lower.hasPrefix("quanto basta") {
            return true
        }
        let amountPattern = #"^(?:\d+(?:[,.]\d+)?|\d+\s+\d+/\d+|\d+/\d+|[½⅓⅔¼¾⅛])\s+"#
        if lower.range(of: amountPattern, options: .regularExpression) != nil {
            return true
        }
        let trailingAmountPattern = #"\s(?:\d+(?:[,.]\d+)?|\d+/\d+|[½⅓⅔¼¾⅛]|q\.b\.|quanto basta)(?:\s+[[:alpha:]\.]+)?$"#
        if lower.range(of: trailingAmountPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return units.contains { lower.hasPrefix("\($0) ") }
    }

    private func looksLikeInstruction(_ line: String) -> Bool {
        let lower = removeListPrefix(line).lowercased()
        let verbs = [
            "aggiungi", "amalgama", "cuoci", "taglia", "mescola", "versa", "inforna",
            "scalda", "sciogli", "lascia", "servi", "impasta", "frulla", "unisci",
            "monta", "stendi", "porta", "riduci", "copri", "trasferisci", "manteca"
        ]
        return verbs.contains { lower.hasPrefix($0) || lower.contains(". \($0)") }
            || line.range(of: #"^\s*\d+[\).]\s+"#, options: .regularExpression) != nil
    }

    private func parseIngredient(_ line: String, evidenceID: String) -> IngredientDraft {
        let cleaned = removeListPrefix(line)
        let trailingPattern = #"^(?<item>.+?)\s+(?<quantity>\d+(?:[,.]\d+)?|\d+/\d+|[½⅓⅔¼¾⅛]|q\.b\.|quanto basta)(?:\s+(?<unit>[[:alpha:]\.]+))?$"#
        if let regex = try? NSRegularExpression(pattern: trailingPattern, options: .caseInsensitive),
           let match = regex.firstMatch(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned)
           ),
           let itemName = capture("item", match: match, text: cleaned),
           let quantityText = capture("quantity", match: match, text: cleaned) {
            let range = DecimalParser.parseRange(quantityText)
            return IngredientDraft(
                originalText: cleaned,
                itemName: itemName,
                quantityText: quantityText,
                quantity: range.minimum,
                quantityMax: range.maximum,
                unit: capture("unit", match: match, text: cleaned),
                optional: cleaned.localizedCaseInsensitiveContains("facoltativ"),
                confidence: 0.78,
                evidenceIDs: [evidenceID]
            )
        }

        let pattern = #"^(?<quantity>(?:\d+(?:[,.]\d+)?|\d+\s+\d+/\d+|\d+/\d+|[½⅓⅔¼¾⅛])(?:\s*[–-]\s*(?:\d+(?:[,.]\d+)?|\d+/\d+))?)?\s*(?<unit>[[:alpha:]\.]+)?\s*(?<item>.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned)
              )
        else {
            return IngredientDraft(
                originalText: cleaned,
                itemName: cleaned,
                confidence: 0.55,
                evidenceIDs: [evidenceID]
            )
        }

        let quantityText = capture("quantity", match: match, text: cleaned)
        var unit = capture("unit", match: match, text: cleaned)
        var itemName = capture("item", match: match, text: cleaned) ?? cleaned
        if let candidate = unit, !units.contains(candidate.lowercased()) {
            itemName = "\(candidate) \(itemName)"
            unit = nil
        }
        let range = DecimalParser.parseRange(quantityText)

        return IngredientDraft(
            originalText: cleaned,
            itemName: itemName.trimmingCharacters(in: .whitespaces),
            quantityText: quantityText,
            quantity: range.minimum,
            quantityMax: range.maximum,
            unit: unit,
            optional: cleaned.localizedCaseInsensitiveContains("facoltativ"),
            confidence: 0.72,
            evidenceIDs: [evidenceID]
        )
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private func capture(
        _ name: String,
        match: NSTextCheckingResult,
        text: String
    ) -> String? {
        let nsRange = match.range(withName: name)
        guard nsRange.location != NSNotFound, let range = Range(nsRange, in: text) else {
            return nil
        }
        let value = String(text[range]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private func removeListPrefix(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"^\s*(?:[-•*]\s*|\d+[\).]\s*)"#,
            with: "",
            options: .regularExpression
        )
    }

    private func cleanLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum SectionMode {
        case unknown
        case ingredients
        case steps
    }
}
