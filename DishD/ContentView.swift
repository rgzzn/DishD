import SwiftUI

/// Compatibility entry view kept at the original Xcode template path.
/// The app's real navigation lives in `RootView`, but retaining this file
/// prevents stale Xcode tabs/references from pointing at a deleted source file.
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview {
    ContentView()
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
            ],
            inMemory: true
        )
}
