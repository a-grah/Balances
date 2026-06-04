import SwiftUI

/// Portfolio Stats + Summary, mirroring the spreadsheet dashboard.
struct StatsPanelView: View {
    let inputs: [StatsInput]

    private var summary: PortfolioSummary { PortfolioStats.summary(inputs) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("Portfolio Stats") {
                stat("Maximum Balance", Fmt.money(PortfolioStats.maxBalance(inputs)))
                stat("Avg Balance (1 Month)", Fmt.money(PortfolioStats.averageBalance(inputs, sinceDays: 30)))
                stat("Avg Balance (3 Months)", Fmt.money(PortfolioStats.averageBalance(inputs, sinceDays: 91)))
                stat("Avg Balance (6 Months)", Fmt.money(PortfolioStats.averageBalance(inputs, sinceDays: 182)))
                stat("Avg Balance (1 Year)", Fmt.money(PortfolioStats.averageBalance(inputs, sinceDays: 365)))
                stat("Total Deposits", Fmt.money(PortfolioStats.totalDeposits(inputs)), tint: .green)
                stat("Total Withdrawals", Fmt.money(PortfolioStats.totalWithdrawals(inputs)), tint: .red)
            }

            section("Summary") {
                stat("Starting Balance", Fmt.money(summary.startingBalance))
                stat("Net Cash Flows", Fmt.money(summary.netCashFlows))
                stat("Current Value", Fmt.money(summary.currentValue))
                stat("Investment Gain (excl. cash flows)", Fmt.money(summary.investmentGain),
                     tint: summary.investmentGain >= 0 ? .green : .red)
                stat("Gain as % of Start + Cash Flows", Fmt.pct(summary.gainPercent),
                     tint: summary.gainPercent >= 0 ? .green : .red)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(spacing: 6) { content() }
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).bold().foregroundStyle(tint)
                .monospacedDigit()
        }
        .font(.callout)
    }
}
