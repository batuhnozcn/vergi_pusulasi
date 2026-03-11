import SwiftUI
import SwiftData

@main
struct Vergi_PusulasiApp: App {
    var sharedModelContainer: ModelContainer = {
        // Buraya kendi modellerimizi ekliyoruz
        let schema = Schema([
            Transaction.self,
            Dividend.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
