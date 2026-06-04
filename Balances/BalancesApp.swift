import SwiftUI

@main
struct BalancesApp: App {
    let persistence = PersistenceController.shared

    init() {
        SeedImporter.seedIfNeeded(context: persistence.container.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .frame(minWidth: 960, minHeight: 640)
        }
        .commands {
            SidebarCommands()
        }
    }
}
