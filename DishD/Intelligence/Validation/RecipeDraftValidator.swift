import Foundation

struct RecipeDraftValidator: Sendable {
    func validate(_ draft: RecipeDraft, evidence: RecipeEvidenceBundle) throws -> RecipeDraft {
        var validated = draft
        let references = evidence.references
        var unsupportedCount = 0

        validated.title = sanitized(validated.title)
        validated.summary = validated.summary.map(sanitized)
        validated.confidence = min(max(validated.confidence, 0), 1)

        validated.ingredientSections = validated.ingredientSections.compactMap { section in
            let ingredients = section.ingredients.compactMap { ingredient -> IngredientDraft? in
                var ingredient = ingredient
                ingredient.originalText = sanitized(ingredient.originalText)
                ingredient.itemName = sanitized(ingredient.itemName)
                ingredient.evidenceIDs = ingredient.evidenceIDs.filter(references.contains)
                ingredient.confidence = min(max(ingredient.confidence, 0), 1)
                guard !ingredient.itemName.isEmpty else { return nil }
                if ingredient.evidenceIDs.isEmpty {
                    unsupportedCount += 1
                    ingredient.quantity = nil
                    ingredient.quantityMax = nil
                    ingredient.quantityText = nil
                    ingredient.unit = nil
                    ingredient.confidence = min(ingredient.confidence, 0.35)
                }
                return ingredient
            }
            guard !ingredients.isEmpty else { return nil }
            return IngredientSectionDraft(
                id: section.id,
                title: section.title.map(sanitized),
                ingredients: ingredients
            )
        }

        validated.steps = validated.steps.compactMap { step in
            var step = step
            step.instruction = sanitized(step.instruction)
            step.evidenceIDs = step.evidenceIDs.filter(references.contains)
            step.confidence = min(max(step.confidence, 0), 1)
            guard !step.instruction.isEmpty else { return nil }
            if step.evidenceIDs.isEmpty {
                unsupportedCount += 1
                step.durationSeconds = nil
                step.temperatureValue = nil
                step.temperatureUnit = nil
                step.confidence = min(step.confidence, 0.35)
            }
            if let temperature = step.temperatureValue, temperature > 350 {
                validated.warnings.append("La fonte indica una temperatura insolita: \(temperature)°. Verifica il valore.")
            }
            return step
        }

        if validated.isRecipe && validated.title.isEmpty {
            validated.title = "Ricetta senza titolo"
            validated.unresolved.append(.init(fieldName: "title", message: "Aggiungi un titolo alla ricetta."))
        }

        if validated.ingredients.isEmpty && validated.steps.isEmpty {
            validated.isRecipe = false
        }

        if validated.ingredients.isEmpty {
            validated.unresolved.append(.init(fieldName: "ingredients", message: "Ingredienti non disponibili nella fonte."))
        }

        if validated.steps.isEmpty {
            validated.unresolved.append(.init(fieldName: "steps", message: "Procedimento non disponibile nella fonte."))
        }

        if unsupportedCount > 0 {
            validated.unresolved.append(
                .init(
                    fieldName: "evidence",
                    message: "\(unsupportedCount) campi non avevano un’evidenza valida e sono stati ridotti."
                )
            )
            validated.confidence = max(0, validated.confidence - (Double(unsupportedCount) * 0.08))
        }

        validated.unresolved = deduplicated(validated.unresolved)
        return validated
    }

    private func sanitized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)ignore\s+(all\s+)?previous\s+instructions"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicated(_ items: [UnresolvedFieldDraft]) -> [UnresolvedFieldDraft] {
        var seen = Set<String>()
        return items.filter { seen.insert("\($0.fieldName)|\($0.message)").inserted }
    }
}
