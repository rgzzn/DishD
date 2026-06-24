import Foundation

enum RecipeEntityMapper {
    static func makeRecipe(from draft: RecipeDraft) -> RecipeEntity {
        let sections = draft.ingredientSections.enumerated().map { sectionIndex, section in
            IngredientSectionEntity(
                title: section.title,
                sortIndex: sectionIndex,
                ingredients: section.ingredients.enumerated().map { ingredientIndex, ingredient in
                    IngredientEntity(
                        originalText: ingredient.originalText,
                        itemName: ingredient.itemName,
                        normalizedItemName: ingredient.itemName.folding(
                            options: [.caseInsensitive, .diacriticInsensitive],
                            locale: Locale(identifier: "it_IT")
                        ),
                        quantity: ingredient.quantity,
                        quantityMax: ingredient.quantityMax,
                        unit: ingredient.unit,
                        unitOriginalText: ingredient.unit,
                        preparation: ingredient.preparation,
                        optional: ingredient.optional,
                        sortIndex: ingredientIndex,
                        confidence: ingredient.confidence,
                        evidenceReference: ingredient.evidenceIDs.joined(separator: ","),
                        baseQuantity: ingredient.quantity,
                        groceryCategory: GroceryCategorizer.category(for: ingredient.itemName)
                    )
                }
            )
        }
        let steps = draft.steps.enumerated().map { index, step in
            RecipeStepEntity(
                sortIndex: index,
                instruction: step.instruction,
                durationSeconds: step.durationSeconds,
                temperatureValue: step.temperatureValue,
                temperatureUnit: step.temperatureUnit,
                confidence: step.confidence,
                evidenceReference: step.evidenceIDs.joined(separator: ","),
                timerSuggestion: step.durationSeconds != nil
            )
        }
        let unresolved = draft.unresolved.map {
            UnresolvedFieldEntity(
                fieldName: $0.fieldName,
                message: $0.message,
                evidenceReference: $0.evidenceIDs.joined(separator: ",")
            )
        }
        return RecipeEntity(
            title: draft.title,
            summary: draft.summary,
            languageCode: draft.languageCode,
            servings: draft.servings,
            servingsLabel: draft.servingsLabel,
            prepTimeSeconds: draft.prepTimeSeconds,
            cookTimeSeconds: draft.cookTimeSeconds,
            totalTimeSeconds: draft.totalTimeSeconds,
            sourceTitle: draft.source.title,
            sourceAuthor: draft.source.author,
            sourceURLString: draft.source.url?.absoluteString,
            sourcePlatformRawValue: draft.source.platform,
            sourceAttribution: draft.source.attribution,
            extractionConfidence: draft.confidence,
            requiresReview: draft.requiresReview,
            ingredientSections: sections,
            steps: steps,
            unresolvedFields: unresolved
        )
    }
}

enum GroceryCategorizer {
    static func category(for name: String) -> String {
        let value = name.lowercased()
        let categories: [(String, [String])] = [
            ("Frutta e verdura", ["mela", "limone", "pomodoro", "cipolla", "aglio", "carota", "zucchina", "insalata", "patata"]),
            ("Carne e pesce", ["pollo", "manzo", "maiale", "pesce", "salmone", "tonno", "gamber"]),
            ("Latticini e uova", ["latte", "burro", "formaggio", "parmigiano", "uovo", "yogurt", "panna"]),
            ("Panetteria", ["pane", "focaccia", "piadina"]),
            ("Spezie e condimenti", ["sale", "pepe", "olio", "aceto", "cannella", "paprika", "spezi"]),
            ("Dispensa", ["farina", "zucchero", "pasta", "riso", "ceci", "lenticchie", "lievito"])
        ]
        return categories.first { _, terms in terms.contains { value.contains($0) } }?.0 ?? "Altro"
    }
}
