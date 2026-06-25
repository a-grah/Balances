import AppIntents
import CoreData

/// `@MainActor` Core Data access layer shared by all App Intents.
///
/// Mirrors the read/write surface of `ScriptingSupport.swift` without
/// depending on `NSApp`, so intents work whether or not a window is open.
@MainActor
enum IntentsDataProvider {

    private static var viewContext: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }

    // MARK: - Fetch

    static func fetchEntries() -> [BalanceEntry] {
        let request = BalanceEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BalanceEntry.date, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }

    static func entries(withIDs ids: [UUID]) -> [BalanceEntry] {
        let idSet = Set(ids)
        return fetchEntries().filter { entry in
            guard let id = entry.id else { return false }
            return idSet.contains(id)
        }
    }

    // MARK: - Computed stats

    static func summary() -> PortfolioSummary {
        PortfolioStats.summary(fetchEntries().statsInputs)
    }

    // MARK: - Create

    /// Inserts a new `BalanceEntry` and saves; returns the corresponding
    /// `BalanceEntryEntity` value so the calling intent can return it directly.
    static func addEntry(
        date: Date,
        balance: Double,
        adjustment: Double,
        transfers: Double,
        note: String?
    ) throws -> BalanceEntryEntity {
        let entry = BalanceEntry(context: viewContext)
        entry.id = UUID()
        entry.date = date
        entry.balance = balance
        entry.adjustment = adjustment
        entry.transfers = transfers
        entry.note = note.flatMap { $0.isEmpty ? nil : $0 }
        try viewContext.save()
        return BalanceEntryEntity(from: entry)
    }
}
