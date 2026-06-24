import Foundation
import FoundationModels

@Generable(description: "A recipe extracted faithfully from supplied evidence.")
struct GeneratedRecipeDraft: Sendable {
    @Guide(description: "True only when the evidence contains a usable recipe.")
    let isRecipe: Bool

    @Guide(description: "Recipe title supported by the evidence, or an empty string.")
    let title: String

    @Guide(description: "Short summary supported by the evidence, or an empty string.")
    let summary: String

    @Guide(description: "BCP-47 language code for the recipe.")
    let languageCode: String

    @Guide(description: "Original servings expression, or an empty string.")
    let servingsText: String

    @Guide(description: "Preparation time in minutes. Use zero when absent.", .range(0...10080))
    let prepTimeMinutes: Int

    @Guide(description: "Cooking time in minutes. Use zero when absent.", .range(0...10080))
    let cookTimeMinutes: Int

    @Guide(description: "Total time in minutes. Use zero when absent.", .range(0...20160))
    let totalTimeMinutes: Int

    @Guide(description: "Ingredient groups in source order.", .maximumCount(20))
    let ingredientSections: [GeneratedIngredientSection]

    @Guide(description: "Recipe steps in source order.", .maximumCount(80))
    let steps: [GeneratedRecipeStep]

    @Guide(description: "Important missing or ambiguous fields.", .maximumCount(30))
    let unresolvedFields: [GeneratedUnresolvedField]

    @Guide(description: "Warnings about suspicious source values.", .maximumCount(20))
    let warnings: [String]

    @Guide(description: "Overall confidence from zero to one.", .range(0...1))
    let overallConfidence: Double

    @Guide(description: "Reason the content is not a recipe, or an empty string.")
    let rejectionReason: String
}

@Generable
struct GeneratedIngredientSection: Sendable {
    @Guide(description: "Section title, or an empty string.")
    let title: String

    @Guide(description: "Ingredients in source order.", .maximumCount(80))
    let ingredients: [GeneratedIngredient]
}

@Generable
struct GeneratedIngredient: Sendable {
    let originalText: String
    let itemName: String

    @Guide(description: "Quantity expression exactly supported by evidence, or empty.")
    let quantityText: String

    @Guide(description: "Unit exactly supported by evidence, or empty.")
    let unitText: String

    @Guide(description: "Preparation note exactly supported by evidence, or empty.")
    let preparation: String

    let optional: Bool

    @Guide(description: "Confidence from zero to one.", .range(0...1))
    let confidence: Double

    @Guide(description: "IDs of supporting evidence items.", .maximumCount(8))
    let evidenceIDs: [String]
}

@Generable
struct GeneratedRecipeStep: Sendable {
    let instruction: String

    @Guide(description: "Explicit duration in minutes. Use zero when absent.", .range(0...10080))
    let durationMinutes: Int

    @Guide(description: "Explicit temperature. Use zero when absent.", .range(0...1000))
    let temperatureValue: Int

    @Guide(description: "Temperature unit such as C or F, or empty.")
    let temperatureUnit: String

    @Guide(description: "Confidence from zero to one.", .range(0...1))
    let confidence: Double

    @Guide(description: "IDs of supporting evidence items.", .maximumCount(8))
    let evidenceIDs: [String]
}

@Generable
struct GeneratedUnresolvedField: Sendable {
    let fieldName: String
    let message: String

    @Guide(description: "IDs of related evidence items.", .maximumCount(8))
    let evidenceIDs: [String]
}
