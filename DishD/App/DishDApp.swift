import SwiftUI
import SwiftData

@main
struct DishDApp: App {
    private let sharedModelContainer = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            if let sharedModelContainer {
                ContentView()
                    .modelContainer(sharedModelContainer)
            } else {
                StartupErrorView()
            }
        }
    }
}
