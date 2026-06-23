import SwiftUI
import SwiftData

struct MealPlannerView: View { @Query private var recipes: [RecipeEntity]; var body: some View { NavigationStack { List { Section("Settimana") { ForEach(["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"], id: \.self) { day in MealSlotCard(day: day, recipeTitle: recipes.first?.title) } } }.navigationTitle("Piano") } } }
struct MealSlotCard: View { let day: String; let recipeTitle: String?; var body: some View { VStack(alignment: .leading) { Text(day).font(.headline); Text(recipeTitle ?? "Tocca per aggiungere una ricetta").foregroundStyle(.secondary) }.accessibilityElement(children: .combine) } }
