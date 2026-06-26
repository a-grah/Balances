import AppIntents
import CoreData

/// Core Data access layer shared by all App Intents.
///
/// Uses `performAndWait` on a background context so all methods are safe to
/// call from any thread or actor — no main-actor dependency required.
enum IntentsDataProvider {

    // MARK: - Fetch (value types only, safe to pass across threads)

    static func statsInputs() -> [StatsInput] {
        let ctx = PersistenceController.shared.container.newBackgroundContext()
        return ctx.performAndWait {
            let request = BalanceEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \BalanceEntry.date, ascending: true)]
            return ((try? ctx.fetch(request)) ?? []).statsInputs
        }
    }

    static func allEntities() -> [BalanceEntryEntity] {
        let ctx = PersistenceController.shared.container.newBackgroundContext()
        return ctx.performAndWait {
            let request = BalanceEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \BalanceEntry.date, ascending: true)]
            return ((try? ctx.fetch(request)) ?? []).map { BalanceEntryEntity(from: $0) }
        }
    }

    static func entities(withIDs ids: [UUID]) -> [BalanceEntryEntity] {
        let idSet = Set(ids)
        let ctx = PersistenceController.shared.container.newBackgroundContext()
        return ctx.performAndWait {
            let request = BalanceEntry.fetchRequest()
            return ((try? ctx.fetch(request)) ?? [])
                .filter { entry in entry.id.map { idSet.contains($0) } ?? false }
                .map { BalanceEntryEntity(from: $0) }
        }
    }

    // MARK: - Computed stats

    static func summary() -> PortfolioSummary {
        PortfolioStats.summary(statsInputs())
    }

    // MARK: - Create

    static func addEntry(
        date: Date,
        balance: Double,
        adjustment: Double,
        transfers: Double,
        note: String?
    ) throws -> BalanceEntryEntity {
        let ctx = PersistenceController.shared.container.newBackgroundContext()
        var savedEntity: BalanceEntryEntity?
        var saveError: Error?
        ctx.performAndWait {
            let entry = BalanceEntry(context: ctx)
            entry.id = UUID()
            entry.date = date
            entry.balance = balance
            entry.adjustment = adjustment
            entry.transfers = transfers
            entry.note = note.flatMap { $0.isEmpty ? nil : $0 }
            do {
                try ctx.save()
                savedEntity = BalanceEntryEntity(from: entry)
            } catch {
                saveError = error
            }
        }
        if let error = saveError { throw error }
        return savedEntity!
    }
}
