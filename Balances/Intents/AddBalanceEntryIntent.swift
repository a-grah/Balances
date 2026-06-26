import AppIntents
import Foundation

/// Adds a dated balance snapshot to the portfolio.
///
/// Mirrors the AppleScript `make new balance entry` command, surfacing the
/// same fields in Shortcuts and Siri.
struct AddBalanceEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Balance Entry"
    static var description = IntentDescription(
        "Adds a dated balance snapshot to Balances.",
        categoryName: "Portfolio"
    )
    static let openAppWhenRun = true

    // MARK: - Parameters

    @Parameter(title: "Date", description: "Date of the snapshot (defaults to today).")
    var date: Date?

    @Parameter(
        title: "Balance",
        description: "Total portfolio value at this date.",
        requestValueDialog: IntentDialog("What is the portfolio balance?")
    )
    var balance: Double

    @Parameter(
        title: "Adjustment",
        description: "Cash flow: positive for a deposit, negative for a withdrawal.",
        default: 0.0
    )
    var adjustment: Double

    @Parameter(title: "Transfers", description: "Transfer amount (optional).", default: 0.0)
    var transfers: Double

    @Parameter(title: "Note", description: "Optional note for this entry.")
    var note: String?

    // MARK: - Summary

    static var parameterSummary: some ParameterSummary {
        Summary("Add balance \(\.$balance) on \(\.$date)")
    }

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ReturnsValue<BalanceEntryEntity> & ProvidesDialog {
        let entryDate = date ?? Date()
        let entity = try IntentsDataProvider.addEntry(
            date: entryDate,
            balance: balance,
            adjustment: adjustment,
            transfers: transfers,
            note: note
        )
        let dialog = "Added \(Fmt.money(balance)) on \(Fmt.day(entryDate))."
        return .result(value: entity, dialog: IntentDialog(stringLiteral: dialog))
    }
}
