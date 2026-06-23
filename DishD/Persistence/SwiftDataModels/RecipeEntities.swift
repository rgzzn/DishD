import Foundation
import SwiftData

@Model
final class RecipeEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String?
    var languageCode: String
    var servings: Decimal?
    var servingsLabel: String?
    var prepTimeSeconds: Int?
    var cookTimeSeconds: Int?
    var totalTimeSeconds: Int?
    var difficultyRawValue: String?
    var cuisine: String?
    var course: String?
    var createdAt: Date
    var updatedAt: Date
    var lastCookedAt: Date?
    var favorite: Bool
    var archived: Bool
    var sourceTitle: String?
    var sourceAuthor: String?
    var sourceURLString: String?
    var sourcePlatformRawValue: String
    var sourceAttribution: String?
    var extractionConfidence: Double
    var requiresReview: Bool
    var userEditedAfterImport: Bool
    var heroImageRelativePath: String?
    var notes: String?
    @Relationship(deleteRule: .cascade, inverse: \IngredientSectionEntity.recipe) var ingredientSections: [IngredientSectionEntity]
    @Relationship(deleteRule: .cascade, inverse: \RecipeStepEntity.recipe) var steps: [RecipeStepEntity]
    @Relationship(deleteRule: .cascade, inverse: \TagEntity.recipe) var tags: [TagEntity]
    @Relationship(deleteRule: .cascade, inverse: \UnresolvedFieldEntity.recipe) var unresolvedFields: [UnresolvedFieldEntity]

    init(id: UUID = UUID(), title: String, summary: String? = nil, languageCode: String = "it", servings: Decimal? = nil, servingsLabel: String? = nil, prepTimeSeconds: Int? = nil, cookTimeSeconds: Int? = nil, totalTimeSeconds: Int? = nil, difficultyRawValue: String? = nil, cuisine: String? = nil, course: String? = nil, createdAt: Date = .now, updatedAt: Date = .now, lastCookedAt: Date? = nil, favorite: Bool = false, archived: Bool = false, sourceTitle: String? = nil, sourceAuthor: String? = nil, sourceURLString: String? = nil, sourcePlatformRawValue: String = "manuale", sourceAttribution: String? = nil, extractionConfidence: Double = 0, requiresReview: Bool = true, userEditedAfterImport: Bool = false, heroImageRelativePath: String? = nil, notes: String? = nil, ingredientSections: [IngredientSectionEntity] = [], steps: [RecipeStepEntity] = [], tags: [TagEntity] = [], unresolvedFields: [UnresolvedFieldEntity] = []) {
        self.id = id; self.title = title; self.summary = summary; self.languageCode = languageCode; self.servings = servings; self.servingsLabel = servingsLabel; self.prepTimeSeconds = prepTimeSeconds; self.cookTimeSeconds = cookTimeSeconds; self.totalTimeSeconds = totalTimeSeconds; self.difficultyRawValue = difficultyRawValue; self.cuisine = cuisine; self.course = course; self.createdAt = createdAt; self.updatedAt = updatedAt; self.lastCookedAt = lastCookedAt; self.favorite = favorite; self.archived = archived; self.sourceTitle = sourceTitle; self.sourceAuthor = sourceAuthor; self.sourceURLString = sourceURLString; self.sourcePlatformRawValue = sourcePlatformRawValue; self.sourceAttribution = sourceAttribution; self.extractionConfidence = extractionConfidence; self.requiresReview = requiresReview; self.userEditedAfterImport = userEditedAfterImport; self.heroImageRelativePath = heroImageRelativePath; self.notes = notes; self.ingredientSections = ingredientSections; self.steps = steps; self.tags = tags; self.unresolvedFields = unresolvedFields
    }
}

@Model
final class IngredientSectionEntity {
    @Attribute(.unique) var id: UUID
    var title: String?
    var sortIndex: Int
    var recipe: RecipeEntity?
    @Relationship(deleteRule: .cascade, inverse: \IngredientEntity.section) var ingredients: [IngredientEntity]
    init(id: UUID = UUID(), title: String? = nil, sortIndex: Int, ingredients: [IngredientEntity] = []) { self.id = id; self.title = title; self.sortIndex = sortIndex; self.ingredients = ingredients }
}

@Model
final class IngredientEntity {
    @Attribute(.unique) var id: UUID
    var originalText: String
    var itemName: String
    var normalizedItemName: String?
    var quantity: Decimal?
    var quantityMax: Decimal?
    var unit: String?
    var unitOriginalText: String?
    var preparation: String?
    var optional: Bool
    var garnish: Bool
    var note: String?
    var sortIndex: Int
    var confidence: Double
    var evidenceReference: String?
    var baseQuantity: Decimal?
    var conversionCategory: String?
    var densityRequired: Bool
    var groceryCategory: String
    var section: IngredientSectionEntity?
    init(id: UUID = UUID(), originalText: String, itemName: String, normalizedItemName: String? = nil, quantity: Decimal? = nil, quantityMax: Decimal? = nil, unit: String? = nil, unitOriginalText: String? = nil, preparation: String? = nil, optional: Bool = false, garnish: Bool = false, note: String? = nil, sortIndex: Int, confidence: Double = 0.6, evidenceReference: String? = nil, baseQuantity: Decimal? = nil, conversionCategory: String? = nil, densityRequired: Bool = false, groceryCategory: String = "Altro") { self.id = id; self.originalText = originalText; self.itemName = itemName; self.normalizedItemName = normalizedItemName; self.quantity = quantity; self.quantityMax = quantityMax; self.unit = unit; self.unitOriginalText = unitOriginalText; self.preparation = preparation; self.optional = optional; self.garnish = garnish; self.note = note; self.sortIndex = sortIndex; self.confidence = confidence; self.evidenceReference = evidenceReference; self.baseQuantity = baseQuantity ?? quantity; self.conversionCategory = conversionCategory; self.densityRequired = densityRequired; self.groceryCategory = groceryCategory }
}

@Model
final class RecipeStepEntity {
    @Attribute(.unique) var id: UUID
    var sortIndex: Int
    var instruction: String
    var title: String?
    var durationSeconds: Int?
    var passiveDurationSeconds: Int?
    var temperatureValue: Decimal?
    var temperatureUnit: String?
    var ingredientReferences: [String]
    var mediaReference: String?
    var confidence: Double
    var evidenceReference: String?
    var timerSuggestion: Bool
    var recipe: RecipeEntity?
    init(id: UUID = UUID(), sortIndex: Int, instruction: String, title: String? = nil, durationSeconds: Int? = nil, passiveDurationSeconds: Int? = nil, temperatureValue: Decimal? = nil, temperatureUnit: String? = nil, ingredientReferences: [String] = [], mediaReference: String? = nil, confidence: Double = 0.6, evidenceReference: String? = nil, timerSuggestion: Bool = false) { self.id = id; self.sortIndex = sortIndex; self.instruction = instruction; self.title = title; self.durationSeconds = durationSeconds; self.passiveDurationSeconds = passiveDurationSeconds; self.temperatureValue = temperatureValue; self.temperatureUnit = temperatureUnit; self.ingredientReferences = ingredientReferences; self.mediaReference = mediaReference; self.confidence = confidence; self.evidenceReference = evidenceReference; self.timerSuggestion = timerSuggestion }
}

@Model
final class TagEntity { @Attribute(.unique) var id: UUID; var name: String; var recipe: RecipeEntity?; init(id: UUID = UUID(), name: String) { self.id = id; self.name = name } }
@Model
final class UnresolvedFieldEntity { @Attribute(.unique) var id: UUID; var fieldName: String; var message: String; var evidenceReference: String?; var recipe: RecipeEntity?; init(id: UUID = UUID(), fieldName: String, message: String, evidenceReference: String? = nil) { self.id = id; self.fieldName = fieldName; self.message = message; self.evidenceReference = evidenceReference } }
