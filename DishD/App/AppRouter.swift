import Observation

@MainActor
@Observable
final class AppRouter {
    var presentedSheet: SheetDestination?

    enum SheetDestination: String, Identifiable {
        case importRecipe

        var id: String { rawValue }
    }
}
