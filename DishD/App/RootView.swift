import SwiftUI
import SwiftData

struct RootView: View {
    @State private var showingImport = false
    var body: some View {
        TabView {
            LibraryView(showingImport: $showingImport).tabItem { Label("Ricette", systemImage: "book.closed") }
            MealPlannerView().tabItem { Label("Piano", systemImage: "calendar") }
            GroceryListView().tabItem { Label("Spesa", systemImage: "cart") }
            SettingsView().tabItem { Label("Impostazioni", systemImage: "gearshape") }
        }
        .sheet(isPresented: $showingImport) { ImportComposerView() }
    }
}
#Preview { RootView().modelContainer(for: [RecipeEntity.self, IngredientSectionEntity.self, IngredientEntity.self, RecipeStepEntity.self, TagEntity.self, UnresolvedFieldEntity.self, ImportJobEntity.self, MealPlanWeekEntity.self, MealPlanEntryEntity.self, GroceryListEntity.self, GroceryItemEntity.self], inMemory: true) }
