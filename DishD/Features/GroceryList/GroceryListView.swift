import SwiftUI
import SwiftData

struct GroceryListView: View { @Query private var recipes: [RecipeEntity]; var body: some View { NavigationStack { List { ForEach(groceryItems(), id: \.self) { item in Label(item, systemImage: "circle") } }.navigationTitle("Spesa") } } private func groceryItems() -> [String] { recipes.flatMap { $0.ingredientSections }.flatMap { $0.ingredients }.map { $0.originalText }.sorted() } }
