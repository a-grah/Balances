import CoreData

/// Bridges Core Data managed objects to the value-type inputs used by
/// the pure calculation layer in PortfolioStats.swift.
extension BalanceEntry {
    var statsInput: StatsInput {
        StatsInput(id: id ?? UUID(),
                   date: date ?? .distantPast,
                   balance: balance,
                   adjustment: adjustment)
    }
}

extension Array where Element == BalanceEntry {
    var statsInputs: [StatsInput] { map(\.statsInput) }
}

extension TSXYear {
    /// Display label: explicit label if present, otherwise the year.
    var displayName: String {
        if let label, !label.isEmpty { return label }
        return String(year)
    }

    var input: TSXYearInput {
        TSXYearInput(sortOrder: Int(sortOrder),
                     year: Int(year),
                     label: label,
                     tsxReturn: tsxReturn,
                     netCashFlows: netCashFlows,
                     actualStart: actualStart,
                     actualEnd: actualEnd)
    }
}

extension Array where Element == TSXYear {
    var inputs: [TSXYearInput] { map(\.input) }
}
