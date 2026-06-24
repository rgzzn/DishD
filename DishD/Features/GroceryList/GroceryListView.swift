import SwiftUI
import SwiftData

struct GroceryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [GroceryListEntity]
    @Query(sort: \RecipeEntity.title) private var recipes: [RecipeEntity]
    @State private var newItem = ""

    private var list: GroceryListEntity? { lists.first }
    private var groupedItems: [(String, [GroceryItemEntity])] {
        Dictionary(grouping: list?.items ?? [], by: \.category)
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Aggiungi elemento", text: $newItem)
                        Button("Aggiungi", systemImage: "plus") {
                            addManualItem()
                        }
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if groupedItems.isEmpty {
                    ContentUnavailableView(
                        "Lista vuota",
                        systemImage: "cart",
                        description: Text("Aggiungi un elemento o importa gli ingredienti da una ricetta.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groupedItems, id: \.0) { category, items in
                        Section(category) {
                            ForEach(items) { item in
                                Button {
                                    item.checked.toggle()
                                    try? modelContext.save()
                                } label: {
                                    HStack {
                                        Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(item.checked ? DishDColor.herbStrong : .secondary)
                                        VStack(alignment: .leading) {
                                            Text(item.name)
                                                .strikethrough(item.checked)
                                            if let detail = [item.quantityText, item.sourceSummary]
                                                .compactMap({ $0 })
                                                .joined(separator: " · ")
                                                .nilIfBlank {
                                                Text(detail)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                delete(offsets, from: items)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spesa")
            .toolbar {
                Menu {
                    ForEach(recipes) { recipe in
                        Button(recipe.title) {
                            add(recipe)
                        }
                    }
                } label: {
                    Label("Da ricetta", systemImage: "cart.badge.plus")
                }
                .disabled(recipes.isEmpty)
            }
            .task { ensureList() }
        }
    }

    private func ensureList() {
        guard lists.isEmpty else { return }
        modelContext.insert(GroceryListEntity())
        try? modelContext.save()
    }

    private func addManualItem() {
        guard let list else {
            ensureList()
            return
        }
        let name = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        list.items.append(
            GroceryItemEntity(
                name: name,
                category: GroceryCategorizer.category(for: name),
                manual: true
            )
        )
        newItem = ""
        try? modelContext.save()
    }

    private func add(_ recipe: RecipeEntity) {
        guard let list else { return }
        for ingredient in recipe.ingredientSections.flatMap(\.ingredients) {
            list.items.append(
                GroceryItemEntity(
                    name: ingredient.itemName,
                    quantityText: [ingredient.quantity?.formatted(.number), ingredient.unit]
                        .compactMap { $0 }
                        .joined(separator: " ")
                        .nilIfBlank,
                    category: ingredient.groceryCategory,
                    sourceSummary: recipe.title
                )
            )
        }
        try? modelContext.save()
    }

    private func delete(_ offsets: IndexSet, from items: [GroceryItemEntity]) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        try? modelContext.save()
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
