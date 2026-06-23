import Foundation

struct RecipeDraft: Identifiable, Sendable {
    let id: UUID
    var isRecipe: Bool
    var title: String
    var servings: Decimal?
    var ingredients: [IngredientDraft]
    var steps: [StepDraft]
    var unresolved: [String]
    var sourceURL: URL?
    var confidence: Double
    init(id: UUID = UUID(), isRecipe: Bool = true, title: String, servings: Decimal? = nil, ingredients: [IngredientDraft], steps: [StepDraft], unresolved: [String] = [], sourceURL: URL? = nil, confidence: Double = 0.6) { self.id = id; self.isRecipe = isRecipe; self.title = title; self.servings = servings; self.ingredients = ingredients; self.steps = steps; self.unresolved = unresolved; self.sourceURL = sourceURL; self.confidence = confidence }
}
struct IngredientDraft: Identifiable, Sendable { let id = UUID(); var originalText: String; var itemName: String; var quantity: Decimal?; var unit: String? }
struct StepDraft: Identifiable, Sendable { let id = UUID(); var instruction: String }
