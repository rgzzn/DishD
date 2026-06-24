import SwiftUI
import SwiftData

@main
struct DishDApp: App {
    private let environment = AppEnvironment.live

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
        .modelContainer(
            for: [
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
            ]
        )
    }
}
