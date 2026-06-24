import AppIntents

struct ImportRecipeIntent: AppIntent {
    static let title: LocalizedStringResource = "Importa una ricetta"
    static let description = IntentDescription("Apre DishD per importare testo, un link, una foto o un PDF.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "DishD è pronto per una nuova ricetta.")
    }
}

struct ShowGroceryListIntent: AppIntent {
    static let title: LocalizedStringResource = "Mostra la lista della spesa"
    static let description = IntentDescription("Apre la lista della spesa locale in DishD.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Apro DishD.")
    }
}

struct DishDShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ImportRecipeIntent(),
            phrases: [
                "Importa una ricetta con \(.applicationName)",
                "Crea una ricetta in \(.applicationName)"
            ],
            shortTitle: "Importa ricetta",
            systemImageName: "square.and.arrow.down"
        )
        AppShortcut(
            intent: ShowGroceryListIntent(),
            phrases: [
                "Mostra la spesa in \(.applicationName)"
            ],
            shortTitle: "Mostra spesa",
            systemImageName: "cart"
        )
    }
}
