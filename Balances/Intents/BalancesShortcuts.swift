import AppIntents

/// Registers Balances' App Intents with Siri and Spotlight so they can be
/// triggered by voice or the Spotlight search bar without opening Shortcuts.
///
/// Call `BalancesShortcuts.updateAppShortcutParameters()` once at app launch
/// to make the system aware of these phrases.
struct BalancesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetPortfolioSummaryIntent(),
            phrases: [
                "Show my portfolio in \(.applicationName)",
                "Get portfolio summary in \(.applicationName)",
                "Check my balance in \(.applicationName)"
            ],
            shortTitle: "Portfolio Summary",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: AddBalanceEntryIntent(),
            phrases: [
                "Add a balance to \(.applicationName)",
                "Log a balance in \(.applicationName)",
                "Add a portfolio entry in \(.applicationName)"
            ],
            shortTitle: "Add Balance Entry",
            systemImageName: "plus.circle"
        )
    }
}
