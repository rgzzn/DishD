import SwiftUI
import SwiftData

struct RootView: View {
    let environment: AppEnvironment
    @State private var router = AppRouter()
    @State private var handledLaunchAutomation = false
    @State private var sharedImportInput: String?
    @State private var sharedImportFileURL: URL?

    var body: some View {
        @Bindable var router = router

        rootContent
            .tint(DishDColor.herbStrong)
            .sheet(item: $router.presentedSheet) { destination in
                switch destination {
                case .importRecipe:
                    ImportComposerView(
                        pipeline: environment.importPipeline,
                        initialInput: launchAutomationInput ?? sharedImportInput,
                        initialFileURL: launchAutomationFileURL ?? sharedImportFileURL,
                        automaticallyAnalyze: launchAutomationShouldAnalyze
                    )
                }
            }
            .task {
                guard !handledLaunchAutomation,
                      launchAutomationInput != nil || launchAutomationFileURL != nil
                else {
                    return
                }
                handledLaunchAutomation = true
                router.presentedSheet = .importRecipe
            }
            .task {
                guard launchAutomationInput == nil,
                      launchAutomationFileURL == nil,
                      let pending = await environment.sharedImportInbox.consumeNext()
                else {
                    return
                }
                sharedImportInput = pending.text
                sharedImportFileURL = pending.fileURL
                router.presentedSheet = .importRecipe
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if launchAutomationOpenFirstRecipe {
            DebugFirstRecipeView()
        } else {
            mainTabs
        }
        #else
        mainTabs
        #endif
    }

    private var mainTabs: some View {
        TabView {
            Tab("Ricette", systemImage: "book.closed") {
                LibraryView {
                    router.presentedSheet = .importRecipe
                }
            }

            Tab("Piano", systemImage: "calendar") {
                MealPlannerView()
            }

            Tab("Spesa", systemImage: "cart") {
                GroceryListView()
            }

            Tab("Impostazioni", systemImage: "gearshape") {
                SettingsView(availabilityChecker: environment.availabilityChecker)
            }
        }
    }

    private var launchAutomationInput: String? {
        #if DEBUG
        ProcessInfo.processInfo.environment["DISHD_UI_TEST_INPUT"]
        #else
        nil
        #endif
    }

    private var launchAutomationShouldAnalyze: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["DISHD_UI_TEST_AUTO_ANALYZE"] == "1"
        #else
        false
        #endif
    }

    private var launchAutomationFileURL: URL? {
        #if DEBUG
        ProcessInfo.processInfo.environment["DISHD_UI_TEST_FILE"].map {
            URL(fileURLWithPath: $0)
        }
        #else
        nil
        #endif
    }

    private var launchAutomationOpenFirstRecipe: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["DISHD_UI_TEST_OPEN_FIRST_RECIPE"] == "1"
        #else
        false
        #endif
    }
}

#if DEBUG
private struct DebugFirstRecipeView: View {
    @Query(sort: \RecipeEntity.updatedAt, order: .reverse) private var recipes: [RecipeEntity]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            if let recipe = recipes.first {
                RecipeDetailView(recipe: recipe)
            } else {
                ProgressView("Preparo la ricetta di verifica")
                    .task {
                        let draft = RecipeDraft(
                            title: "Pancake",
                            servings: 12,
                            ingredientSections: [
                                IngredientSectionDraft(
                                    ingredients: [
                                        .init(originalText: "Farina 00 125 g", itemName: "Farina 00", quantityText: "125", quantity: 125, unit: "g"),
                                        .init(originalText: "Latte intero 200 g", itemName: "Latte intero", quantityText: "200", quantity: 200, unit: "g"),
                                        .init(originalText: "Burro 25 g", itemName: "Burro", quantityText: "25", quantity: 25, unit: "g"),
                                        .init(originalText: "Uova medie 2", itemName: "Uova medie", quantityText: "2", quantity: 2),
                                        .init(originalText: "Sale fino 1 pizzico", itemName: "Sale fino", quantityText: "1", quantity: 1, unit: "pizzico"),
                                        .init(originalText: "Sciroppo di acero q.b.", itemName: "Sciroppo di acero", quantityText: "q.b.")
                                    ]
                                )
                            ],
                            steps: [
                                .init(instruction: "Mescola gli ingredienti e cuoci i pancake fino a doratura.")
                            ],
                            confidence: 1,
                            extractionMethod: .structuredWeb
                        )
                        modelContext.insert(RecipeEntityMapper.makeRecipe(from: draft))
                        try? modelContext.save()
                    }
            }
        }
    }
}
#endif

#Preview {
    RootView(environment: .live)
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
