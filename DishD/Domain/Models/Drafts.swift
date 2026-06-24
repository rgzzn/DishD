import Foundation

struct RecipeDraft: Identifiable, Sendable, Codable, Equatable {
    var id: UUID
    var isRecipe: Bool
    var title: String
    var summary: String?
    var languageCode: String
    var servings: Decimal?
    var servingsLabel: String?
    var prepTimeSeconds: Int?
    var cookTimeSeconds: Int?
    var totalTimeSeconds: Int?
    var ingredientSections: [IngredientSectionDraft]
    var steps: [StepDraft]
    var unresolved: [UnresolvedFieldDraft]
    var warnings: [String]
    var source: RecipeSourceDraft
    var confidence: Double
    var extractionMethod: ExtractionMethod
    var referenceImageURL: URL?
    var generatedImageURL: URL?

    init(
        id: UUID = UUID(),
        isRecipe: Bool = true,
        title: String = "",
        summary: String? = nil,
        languageCode: String = "it",
        servings: Decimal? = nil,
        servingsLabel: String? = nil,
        prepTimeSeconds: Int? = nil,
        cookTimeSeconds: Int? = nil,
        totalTimeSeconds: Int? = nil,
        ingredientSections: [IngredientSectionDraft] = [],
        steps: [StepDraft] = [],
        unresolved: [UnresolvedFieldDraft] = [],
        warnings: [String] = [],
        source: RecipeSourceDraft = .manual,
        confidence: Double = 0,
        extractionMethod: ExtractionMethod = .manual,
        referenceImageURL: URL? = nil,
        generatedImageURL: URL? = nil
    ) {
        self.id = id
        self.isRecipe = isRecipe
        self.title = title
        self.summary = summary
        self.languageCode = languageCode
        self.servings = servings
        self.servingsLabel = servingsLabel
        self.prepTimeSeconds = prepTimeSeconds
        self.cookTimeSeconds = cookTimeSeconds
        self.totalTimeSeconds = totalTimeSeconds
        self.ingredientSections = ingredientSections
        self.steps = steps
        self.unresolved = unresolved
        self.warnings = warnings
        self.source = source
        self.confidence = confidence
        self.extractionMethod = extractionMethod
        self.referenceImageURL = referenceImageURL
        self.generatedImageURL = generatedImageURL
    }

    var ingredients: [IngredientDraft] {
        ingredientSections.flatMap(\.ingredients)
    }

    var requiresReview: Bool {
        !unresolved.isEmpty || confidence < 0.78
    }
}

struct IngredientSectionDraft: Identifiable, Sendable, Codable, Equatable {
    var id: UUID
    var title: String?
    var ingredients: [IngredientDraft]

    init(id: UUID = UUID(), title: String? = nil, ingredients: [IngredientDraft] = []) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
    }
}

struct IngredientDraft: Identifiable, Sendable, Codable, Equatable {
    var id: UUID
    var originalText: String
    var itemName: String
    var quantityText: String?
    var quantity: Decimal?
    var quantityMax: Decimal?
    var unit: String?
    var preparation: String?
    var optional: Bool
    var confidence: Double
    var evidenceIDs: [String]

    init(
        id: UUID = UUID(),
        originalText: String,
        itemName: String,
        quantityText: String? = nil,
        quantity: Decimal? = nil,
        quantityMax: Decimal? = nil,
        unit: String? = nil,
        preparation: String? = nil,
        optional: Bool = false,
        confidence: Double = 0.6,
        evidenceIDs: [String] = []
    ) {
        self.id = id
        self.originalText = originalText
        self.itemName = itemName
        self.quantityText = quantityText
        self.quantity = quantity
        self.quantityMax = quantityMax
        self.unit = unit
        self.preparation = preparation
        self.optional = optional
        self.confidence = confidence
        self.evidenceIDs = evidenceIDs
    }
}

struct StepDraft: Identifiable, Sendable, Codable, Equatable {
    var id: UUID
    var instruction: String
    var durationSeconds: Int?
    var temperatureValue: Decimal?
    var temperatureUnit: String?
    var confidence: Double
    var evidenceIDs: [String]

    init(
        id: UUID = UUID(),
        instruction: String,
        durationSeconds: Int? = nil,
        temperatureValue: Decimal? = nil,
        temperatureUnit: String? = nil,
        confidence: Double = 0.6,
        evidenceIDs: [String] = []
    ) {
        self.id = id
        self.instruction = instruction
        self.durationSeconds = durationSeconds
        self.temperatureValue = temperatureValue
        self.temperatureUnit = temperatureUnit
        self.confidence = confidence
        self.evidenceIDs = evidenceIDs
    }
}

struct UnresolvedFieldDraft: Identifiable, Sendable, Codable, Equatable {
    var id: UUID
    var fieldName: String
    var message: String
    var evidenceIDs: [String]

    init(
        id: UUID = UUID(),
        fieldName: String,
        message: String,
        evidenceIDs: [String] = []
    ) {
        self.id = id
        self.fieldName = fieldName
        self.message = message
        self.evidenceIDs = evidenceIDs
    }
}

struct RecipeSourceDraft: Sendable, Codable, Equatable {
    var title: String?
    var author: String?
    var url: URL?
    var platform: String
    var attribution: String?
    var imageURL: URL? = nil

    static let manual = RecipeSourceDraft(
        title: nil,
        author: nil,
        url: nil,
        platform: "manuale",
        attribution: nil
    )
}

enum ExtractionMethod: String, Sendable, Codable, Equatable {
    case foundationModels
    case structuredWeb
    case deterministicText
    case manual

    var italianLabel: String {
        switch self {
        case .foundationModels: "Apple Intelligence"
        case .structuredWeb: "Dati strutturati del sito"
        case .deterministicText: "Analisi locale"
        case .manual: "Inserimento manuale"
        }
    }
}
