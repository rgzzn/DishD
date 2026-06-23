import OSLog
import SwiftData

enum AppModelContainer {
    private static let logger = Logger(subsystem: AppBrand.bundleIdentifier, category: "SwiftData")

    static let schema = Schema([
        RecipeEntity.self,
        IngredientSectionEntity.self,
        IngredientEntity.self,
        RecipeStepEntity.self,
        TagEntity.self,
        UnresolvedFieldEntity.self,
        ImportJobEntity.self,
        MealPlanWeekEntity.self,
        MealPlanEntryEntity.self,
        GroceryListEntity.self,
        GroceryItemEntity.self
    ])

    static func make() -> ModelContainer? {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("Persistent SwiftData store unavailable. Starting with temporary in-memory store. Error: \(error.localizedDescription, privacy: .public)")
            return makeInMemoryFallback()
        }
    }

    private static func makeInMemoryFallback() -> ModelContainer? {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.fault("In-memory SwiftData fallback failed. Error: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
