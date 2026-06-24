import Foundation

struct RecipeJSONLDParser: Sendable {
    func parse(html: String, sourceURL: URL) -> StructuredWebRecipe? {
        let pattern = #"(?is)<script[^>]+type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonText = String(html[range])
                .replacingOccurrences(of: "<!--", with: "")
                .replacingOccurrences(of: "-->", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = jsonText.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let recipe = findRecipe(in: object)
            else {
                continue
            }
            return makeRecipe(from: recipe, sourceURL: sourceURL)
        }
        return nil
    }

    private func findRecipe(in object: Any) -> [String: Any]? {
        if let dictionary = object as? [String: Any] {
            if isRecipeType(dictionary["@type"]) {
                return dictionary
            }
            for key in ["@graph", "mainEntity", "itemListElement"] {
                if let nested = dictionary[key], let recipe = findRecipe(in: nested) {
                    return recipe
                }
            }
        }
        if let array = object as? [Any] {
            for item in array {
                if let recipe = findRecipe(in: item) {
                    return recipe
                }
            }
        }
        return nil
    }

    private func isRecipeType(_ value: Any?) -> Bool {
        if let string = value as? String {
            return string.caseInsensitiveCompare("Recipe") == .orderedSame
        }
        if let values = value as? [String] {
            return values.contains { $0.caseInsensitiveCompare("Recipe") == .orderedSame }
        }
        return false
    }

    private func makeRecipe(
        from json: [String: Any],
        sourceURL: URL
    ) -> StructuredWebRecipe? {
        let title = string(json["name"]) ?? ""
        let ingredientStrings = stringArray(json["recipeIngredient"])
        let instructionStrings = instructions(json["recipeInstructions"])
        guard !title.isEmpty, !ingredientStrings.isEmpty || !instructionStrings.isEmpty else {
            return nil
        }

        let source = RecipeSourceDraft(
            title: title,
            author: author(json["author"]),
            url: sourceURL,
            platform: sourceURL.host ?? "web",
            attribution: sourceURL.host,
            imageURL: imageURL(json["image"], relativeTo: sourceURL)
        )
        var evidence: [EvidenceItem] = []

        let titleEvidence = EvidenceItem(
            kind: .title,
            text: title,
            provenance: .init(source: source.platform, location: "JSON-LD name")
        )
        evidence.append(titleEvidence)

        let ingredients = ingredientStrings.map { original -> IngredientDraft in
            let item = EvidenceItem(
                kind: .ingredient,
                text: original,
                provenance: .init(source: source.platform, location: "JSON-LD recipeIngredient")
            )
            evidence.append(item)
            return parseIngredient(original, evidenceID: item.reference)
        }

        let steps = instructionStrings.map { instruction -> StepDraft in
            let item = EvidenceItem(
                kind: .instruction,
                text: instruction,
                provenance: .init(source: source.platform, location: "JSON-LD recipeInstructions")
            )
            evidence.append(item)
            return StepDraft(
                instruction: instruction,
                confidence: 0.98,
                evidenceIDs: [item.reference]
            )
        }

        let servingsText = string(json["recipeYield"])
            ?? (json["recipeYield"] as? [String])?.first
        var unresolved: [UnresolvedFieldDraft] = []
        if servingsText == nil {
            unresolved.append(.init(fieldName: "servings", message: "Porzioni non specificate nella pagina."))
        }
        if ingredients.isEmpty {
            unresolved.append(.init(fieldName: "ingredients", message: "Ingredienti non presenti nei dati strutturati."))
        }
        if steps.isEmpty {
            unresolved.append(.init(fieldName: "steps", message: "Procedimento non presente nei dati strutturati."))
        }

        let draft = RecipeDraft(
            title: title,
            summary: string(json["description"]),
            languageCode: "it",
            servings: DecimalParser.parse(servingsText?.firstNumber),
            servingsLabel: servingsText,
            prepTimeSeconds: durationSeconds(string(json["prepTime"])),
            cookTimeSeconds: durationSeconds(string(json["cookTime"])),
            totalTimeSeconds: durationSeconds(string(json["totalTime"])),
            ingredientSections: ingredients.isEmpty ? [] : [.init(ingredients: ingredients)],
            steps: steps,
            unresolved: unresolved,
            source: source,
            confidence: 0.96,
            extractionMethod: .structuredWeb
        )
        return StructuredWebRecipe(
            draft: draft,
            evidence: RecipeEvidenceBundle(items: evidence, source: source)
        )
    }

    private func parseIngredient(_ text: String, evidenceID: String) -> IngredientDraft {
        let trailingPattern = #"^(?<item>.+?)\s+(?<quantity>\d+(?:[,.]\d+)?|\d+/\d+|[½⅓⅔¼¾⅛]|q\.b\.)(?:\s+(?<unit>[[:alpha:]\.]+))?$"#
        if let regex = try? NSRegularExpression(pattern: trailingPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let itemRange = Range(match.range(withName: "item"), in: text),
           let quantityRange = Range(match.range(withName: "quantity"), in: text) {
            let itemName = String(text[itemRange]).trimmingCharacters(in: .whitespaces)
            let quantityText = String(text[quantityRange])
            let unitRange = match.range(withName: "unit")
            let unit = unitRange.location == NSNotFound
                ? nil
                : Range(unitRange, in: text).map { String(text[$0]) }
            return IngredientDraft(
                originalText: text,
                itemName: itemName,
                quantityText: quantityText,
                quantity: DecimalParser.parse(quantityText),
                unit: unit,
                confidence: 0.97,
                evidenceIDs: [evidenceID]
            )
        }

        let parser = DeterministicTextRecipeParser()
        if let result = parser.parse("Titolo\nIngredienti\n\(text)", source: .manual),
           let ingredient = result.draft.ingredients.first {
            var ingredient = ingredient
            ingredient.evidenceIDs = [evidenceID]
            ingredient.confidence = 0.96
            return ingredient
        }
        return IngredientDraft(
            originalText: text,
            itemName: text,
            confidence: 0.9,
            evidenceIDs: [evidenceID]
        )
    }

    private func instructions(_ value: Any?) -> [String] {
        if let string = value as? String {
            return [clean(string)]
        }
        guard let array = value as? [Any] else { return [] }
        return array.flatMap { item -> [String] in
            if let string = item as? String {
                return [clean(string)]
            }
            guard let dictionary = item as? [String: Any] else { return [] }
            if let text = string(dictionary["text"]) {
                return [clean(text)]
            }
            if let nested = dictionary["itemListElement"] {
                return instructions(nested)
            }
            return []
        }
        .filter { !$0.isEmpty }
    }

    private func stringArray(_ value: Any?) -> [String] {
        if let values = value as? [String] {
            return values.map(clean).filter { !$0.isEmpty }
        }
        if let value = value as? String {
            return [clean(value)]
        }
        return []
    }

    private func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            clean(string).nilIfBlank
        case let number as NSNumber:
            number.stringValue
        default:
            nil
        }
    }

    private func author(_ value: Any?) -> String? {
        if let string = value as? String { return clean(string) }
        if let dictionary = value as? [String: Any] { return string(dictionary["name"]) }
        if let array = value as? [[String: Any]] {
            return array.compactMap { string($0["name"]) }.joined(separator: ", ").nilIfBlank
        }
        return nil
    }

    private func imageURL(_ value: Any?, relativeTo sourceURL: URL) -> URL? {
        let candidate: String?
        switch value {
        case let string as String:
            candidate = string
        case let values as [String]:
            candidate = values.first
        case let dictionary as [String: Any]:
            candidate = string(dictionary["contentUrl"])
                ?? string(dictionary["url"])
                ?? string(dictionary["@id"])
        case let values as [[String: Any]]:
            candidate = values.lazy.compactMap {
                string($0["contentUrl"]) ?? string($0["url"]) ?? string($0["@id"])
            }.first
        default:
            candidate = nil
        }
        guard let candidate else { return nil }
        return URL(string: candidate, relativeTo: sourceURL)?.absoluteURL
    }

    private func durationSeconds(_ value: String?) -> Int? {
        guard let value else { return nil }
        let pattern = #"^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value))
        else {
            return nil
        }
        func component(_ index: Int) -> Int {
            guard match.range(at: index).location != NSNotFound,
                  let range = Range(match.range(at: index), in: value)
            else { return 0 }
            return Int(value[range]) ?? 0
        }
        let seconds = component(1) * 86_400 + component(2) * 3_600 + component(3) * 60 + component(4)
        return seconds > 0 ? seconds : nil
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"(?s)<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: #"\\u([0-9a-fA-F]{4})"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var firstNumber: String? {
        range(of: #"\d+(?:[,.]\d+)?"#, options: .regularExpression).map { String(self[$0]) }
    }
}
