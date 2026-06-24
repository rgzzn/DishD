import SwiftUI
import SwiftData

struct MealPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeEntity.title) private var recipes: [RecipeEntity]
    @Query(sort: \MealPlanWeekEntity.weekStartDate, order: .reverse) private var weeks: [MealPlanWeekEntity]
    @State private var weekOffset = 0

    private let calendar = Calendar(identifier: .iso8601)
    private let dayNames = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]

    private var weekStart: Date {
        let today = Date.now
        let weekday = calendar.component(.weekday, from: today)
        let mondayDistance = (weekday + 5) % 7
        let currentMonday = calendar.date(byAdding: .day, value: -mondayDistance, to: calendar.startOfDay(for: today)) ?? today
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentMonday) ?? currentMonday
    }

    private var currentWeek: MealPlanWeekEntity? {
        weeks.first { calendar.isDate($0.weekStartDate, inSameDayAs: weekStart) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button("Settimana precedente", systemImage: "chevron.left") {
                            weekOffset -= 1
                        }
                        Spacer()
                        Text(weekStart.formatted(.dateTime.day().month()))
                            .font(.headline)
                        Spacer()
                        Button("Settimana successiva", systemImage: "chevron.right") {
                            weekOffset += 1
                        }
                    }
                    .labelStyle(.iconOnly)
                }

                ForEach(0..<7, id: \.self) { day in
                    Section(dayNames[day]) {
                        MealSlotCard(
                            day: dayNames[day],
                            recipeTitle: entry(for: day)?.recipe?.title
                        )
                        Menu("Scegli ricetta", systemImage: "plus") {
                            ForEach(recipes) { recipe in
                                Button(recipe.title) {
                                    assign(recipe, to: day)
                                }
                            }
                        }
                        .disabled(recipes.isEmpty)
                    }
                }
            }
            .navigationTitle("Piano")
            .task(id: weekOffset) {
                ensureWeek()
            }
        }
    }

    private func ensureWeek() {
        guard currentWeek == nil else { return }
        modelContext.insert(MealPlanWeekEntity(weekStartDate: weekStart))
        try? modelContext.save()
    }

    private func entry(for day: Int) -> MealPlanEntryEntity? {
        currentWeek?.entries.first { $0.dayOffset == day && $0.mealSlot == "cena" }
    }

    private func assign(_ recipe: RecipeEntity, to day: Int) {
        guard let week = currentWeek else {
            ensureWeek()
            return
        }
        if let existing = entry(for: day) {
            existing.recipe = recipe
        } else {
            week.entries.append(
                MealPlanEntryEntity(
                    dayOffset: day,
                    mealSlot: "cena",
                    plannedServings: recipe.servings,
                    recipe: recipe
                )
            )
        }
        try? modelContext.save()
    }
}

struct MealSlotCard: View {
    let day: String
    let recipeTitle: String?

    var body: some View {
        HStack {
            Image(systemName: recipeTitle == nil ? "fork.knife.circle" : "checkmark.circle.fill")
                .foregroundStyle(recipeTitle == nil ? .secondary : DishDColor.herbStrong)
            VStack(alignment: .leading) {
                Text("Cena").font(.caption).foregroundStyle(.secondary)
                Text(recipeTitle ?? "Nessuna ricetta")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day), cena, \(recipeTitle ?? "nessuna ricetta")")
    }
}
