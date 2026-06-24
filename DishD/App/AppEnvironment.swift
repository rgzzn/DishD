import Foundation

struct AppEnvironment {
    let importPipeline: RecipeImportPipeline
    let availabilityChecker: AppleSystemModelAvailabilityChecker
    let sharedImportInbox: SharedImportInbox

    static let live = AppEnvironment(
        importPipeline: RecipeImportPipeline(),
        availabilityChecker: AppleSystemModelAvailabilityChecker(),
        sharedImportInbox: SharedImportInbox()
    )
}
