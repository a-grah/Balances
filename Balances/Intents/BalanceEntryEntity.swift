import AppIntents
import Foundation

/// App Intents entity representing a single portfolio balance snapshot.
///
/// Exposes `BalanceEntry` to the Shortcuts app so users can query entries,
/// feed them into other actions, or display their details.
struct BalanceEntryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Balance Entry"
    static var defaultQuery = BalanceEntryQuery()

    // MARK: - Identity

    var id: UUID

    // MARK: - Properties (surfaced in the Shortcuts "Get Details" action)

    @Property(title: "Date")
    var date: Date

    @Property(title: "Balance")
    var balance: Double

    @Property(title: "Adjustment")
    var adjustment: Double

    @Property(title: "Transfers")
    var transfers: Double

    @Property(title: "Note")
    var note: String?

    // MARK: - Display

    var displayRepresentation: DisplayRepresentation {
        let subtitle = note.map { LocalizedStringResource(stringLiteral: $0) }
        return DisplayRepresentation(
            title: "\(Fmt.day(date)) — \(Fmt.money(balance))",
            subtitle: subtitle
        )
    }

    // MARK: - Init

    init(from entry: BalanceEntry) {
        self.id = entry.id ?? UUID()
        self.date = entry.date ?? .distantPast
        self.balance = entry.balance
        self.adjustment = entry.adjustment
        self.transfers = entry.transfers
        self.note = entry.note
    }
}

// MARK: - Query

struct BalanceEntryQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [BalanceEntryEntity] {
        IntentsDataProvider.entries(withIDs: identifiers).map { BalanceEntryEntity(from: $0) }
    }

    /// Returns the most recent entries as suggestions in the Shortcuts picker.
    @MainActor
    func suggestedEntities() async throws -> [BalanceEntryEntity] {
        let entries = IntentsDataProvider.fetchEntries()
        return entries.suffix(20).reversed().map { BalanceEntryEntity(from: $0) }
    }
}
