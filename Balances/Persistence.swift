import CoreData

/// Loads the Core Data stack backed by a SQLite store in the app's
/// Application Support container.
struct PersistenceController {
    static let shared = PersistenceController()

    /// In-memory variant for SwiftUI previews.
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.container.viewContext
        for i in 0..<12 {
            let e = BalanceEntry(context: ctx)
            e.id = UUID()
            e.date = Calendar.current.date(byAdding: .month, value: -i, to: Date())!
            e.balance = 100_000 + Double(i) * 5_000
            e.adjustment = i % 3 == 0 ? 2_000 : 0
        }
        ctx.saveLoggingErrors()
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Balances")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        container.viewContext.saveLoggingErrors()
    }
}

extension NSManagedObjectContext {
    /// Saves pending changes, logging a failure instead of discarding it.
    ///
    /// Preferred over `try? save()`: the editors dismiss themselves immediately
    /// after saving, so a swallowed error reads to the user as an accepted edit.
    func saveLoggingErrors(_ site: String = #function) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            let nsError = error as NSError
            NSLog("Core Data save error in \(site): \(nsError), \(nsError.userInfo)")
        }
    }
}
