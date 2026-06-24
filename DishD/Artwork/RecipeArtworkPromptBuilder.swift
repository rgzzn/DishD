import Foundation
import ImagePlayground

enum RecipeArtworkPromptBuilder {
    static func concepts(for draft: RecipeDraft) -> [ImagePlaygroundConcept] {
        concepts(
            title: draft.title,
            summary: draft.summary,
            ingredients: draft.ingredients.map(\.originalText)
        )
    }

    static func concepts(for recipe: RecipeEntity) -> [ImagePlaygroundConcept] {
        concepts(
            title: recipe.title,
            summary: recipe.summary,
            ingredients: recipe.ingredientSections
                .sorted { $0.sortIndex < $1.sortIndex }
                .flatMap { section in
                    section.ingredients.sorted { $0.sortIndex < $1.sortIndex }
                }
                .map(\.originalText)
        )
    }

    private static func concepts(
        title: String,
        summary: String?,
        ingredients: [String]
    ) -> [ImagePlaygroundConcept] {
        let uniqueIngredients = ingredients.reduce(into: [String]()) { result, ingredient in
            let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !result.contains(where: {
                      $0.caseInsensitiveCompare(trimmed) == .orderedSame
                  })
            else {
                return
            }
            result.append(trimmed)
        }
        let ingredientText = uniqueIngredients.prefix(12).joined(separator: ", ")
        let description = """
        Crea una copertina curata del piatto finito “\(title)”.
        Mostra il cibo come protagonista, ben impiattato, appetitoso e riconoscibile.
        Ingredienti caratteristici: \(ingredientText).
        \(summary ?? "")
        Inquadratura ravvicinata, luce naturale morbida, composizione pulita, senza testo, loghi, persone o utensili che nascondano il piatto.
        """
        return [
            .extracted(
                from: description,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        ]
    }
}
