import Foundation

actor TextRecipeExtractor {
    func extract(from text: String, sourceURL: URL? = nil) async -> RecipeDraft {
        let lines = text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let lower = text.lowercased()
        let hasCookingSignals = ["ingredient", "cuoci", "cottura", "mescola", "taglia", "forno", "sale", "pepe", "farina"].contains { lower.contains($0) }
        guard hasCookingSignals else { return RecipeDraft(isRecipe: false, title: "Contenuto non ricetta", ingredients: [], steps: [], unresolved: ["Ingredienti e procedimento non sufficienti"], sourceURL: sourceURL, confidence: 0.2) }
        let title = lines.first ?? "Ricetta importata"
        let servings = Self.servings(in: title + "\n" + text)
        var ingredients: [IngredientDraft] = []
        var steps: [StepDraft] = []
        for line in lines.dropFirst() {
            if Self.looksLikeIngredient(line) { ingredients.append(Self.parseIngredient(line)) }
            else if Self.looksLikeStep(line) { steps.append(StepDraft(instruction: line)) }
        }
        if ingredients.isEmpty { ingredients = lines.filter(Self.looksLikeIngredient).map(Self.parseIngredient) }
        if steps.isEmpty { steps = lines.filter(Self.looksLikeStep).map { StepDraft(instruction: $0) } }
        var unresolved: [String] = []
        if servings == nil { unresolved.append("Porzioni non specificate") }
        if !lower.contains("min") && !lower.contains("ora") { unresolved.append("Tempi non specificati") }
        if !lower.contains("°") { unresolved.append("Temperatura non specificata") }
        return RecipeDraft(title: title, servings: servings, ingredients: ingredients, steps: steps, unresolved: unresolved, sourceURL: sourceURL, confidence: ingredients.isEmpty || steps.isEmpty ? 0.45 : 0.78)
    }
    private static func servings(in text: String) -> Decimal? { let pattern = #"(?:per|porzioni:?|persone:?)\s*(\d+)"#; guard let r = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive), let m = r.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(m.range(at: 1), in: text) else { return nil }; return Decimal(string: String(text[range])) }
    private static func looksLikeIngredient(_ line: String) -> Bool { line.range(of: #"^(\d+[\d\s\/,.]*|[½⅓⅔¼¾⅛]|q\.b\.|qb|quanto basta)?\s*(g|kg|ml|l|cucchiai?|cucchiaini?|spicchi?|uova?|limoni?|mele?|sale|pepe|farina|acqua|olio|burro|parmigiano|spaghetti|cannella)\b"#, options: [.regularExpression, .caseInsensitive]) != nil }
    private static func looksLikeStep(_ line: String) -> Bool { ["cuoci", "taglia", "mescola", "aggiungi", "sciogli", "manteca", "lascia", "inforna", "servi"].contains { line.lowercased().contains($0) } }
    private static func parseIngredient(_ line: String) -> IngredientDraft { let parts = line.split(separator: " ", maxSplits: 2).map(String.init); let quantity = DecimalParser.parse(parts.first); let unit = quantity == nil ? nil : (parts.count > 1 ? parts[1] : nil); let item = quantity == nil ? line : (parts.count > 2 ? parts[2] : line); return IngredientDraft(originalText: line, itemName: item, quantity: quantity, unit: unit) }
}
