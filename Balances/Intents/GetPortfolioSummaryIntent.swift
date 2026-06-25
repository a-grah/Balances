import AppIntents

/// Returns a portfolio performance summary from Balances.
///
/// The typed return value is `currentValue` (a `Double`) so it can be piped
/// into other Shortcuts actions. The confirmation dialog reports all key
/// figures: current value, investment gain, gain %, and net cash flows.
struct GetPortfolioSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Portfolio Summary"
    static var description = IntentDescription(
        "Returns the current portfolio value and performance summary from Balances.",
        categoryName: "Portfolio"
    )

    // No parameters — reads whatever is in the app's data store.

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let summary = IntentsDataProvider.summary()
        let gainSign = summary.investmentGain >= 0 ? "+" : ""
        let dialog = """
            Current value: \(Fmt.money(summary.currentValue))
            Investment gain: \(gainSign)\(Fmt.money(summary.investmentGain)) (\(gainSign)\(Fmt.pct(summary.gainPercent)))
            Net cash flows: \(Fmt.money(summary.netCashFlows))
            """
        return .result(value: summary.currentValue, dialog: IntentDialog(stringLiteral: dialog))
    }
}
