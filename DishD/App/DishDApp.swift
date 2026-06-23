import SwiftUI
import SwiftData

@main
struct DishDApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RecipeEntity.self, IngredientSectionEntity.self, IngredientEntity.self, RecipeStepEntity.self, TagEntity.self, UnresolvedFieldEntity.self,
            ImportJobEntity.self, MealPlanWeekEntity.self, MealPlanEntryEntity.self, GroceryListEntity.self, GroceryItemEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do { return try ModelContainer(for: schema, configurations: [configuration]) }
        catch { preconditionFailure("Impossibile creare il database locale DishD: \(error.localizedDescription)") }
    }()
    var body: some Scene { WindowGroup { RootView() }.modelContainer(sharedModelContainer) }
}
