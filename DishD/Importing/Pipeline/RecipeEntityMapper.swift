import Foundation

enum RecipeEntityMapper {
    static func makeRecipe(from draft: RecipeDraft) -> RecipeEntity {
        let section = IngredientSectionEntity(title: nil, sortIndex: 0, ingredients: draft.ingredients.enumerated().map { index, ingredient in IngredientEntity(originalText: ingredient.originalText, itemName: ingredient.itemName, quantity: ingredient.quantity, unit: ingredient.unit, unitOriginalText: ingredient.unit, sortIndex: index, confidence: draft.confidence) })
        let steps = draft.steps.enumerated().map { index, step in RecipeStepEntity(sortIndex: index, instruction: step.instruction, confidence: draft.confidence) }
        let unresolved = draft.unresolved.map { UnresolvedFieldEntity(fieldName: $0, message: $0) }
        return RecipeEntity(title: draft.title, languageCode: "it", servings: draft.servings, sourceURLString: draft.sourceURL?.absoluteString, sourcePlatformRawValue: draft.sourceURL == nil ? "manuale" : "web", extractionConfidence: draft.confidence, requiresReview: !draft.unresolved.isEmpty, ingredientSections: [section], steps: steps, unresolvedFields: unresolved)
    }
}
