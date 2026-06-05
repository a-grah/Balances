import Foundation

/// A single point on the balance chart.
struct BalancePoint: Identifiable {
    let id: UUID
    let date: Date
    let balance: Double
    /// Balance with cumulative cash flows removed (investment-only performance).
    let adjusted: Double
}

/// Pure portfolio calculations, mirroring the spreadsheet formulas.
/// Operates on plain value snapshots so it stays testable and UI-agnostic.
struct StatsInput {
    let id: UUID
    let date: Date
    let balance: Double
    let adjustment: Double
}

struct PortfolioSummary {
    var startingBalance: Double
    var netCashFlows: Double
    var currentValue: Double
    /// End − Start − Σ cash flows.
    var investmentGain: Double
    /// investmentGain / (Start + Σ cash flows).
    var gainPercent: Double
}

enum PortfolioStats {

    /// Builds chart points sorted ascending by date, computing the
    /// "Adjusted Balance" series = balance − running sum of cash flows.
    static func series(from entries: [StatsInput]) -> [BalancePoint] {
        let sorted = entries.sorted { $0.date < $1.date }
        var running = 0.0
        var points: [BalancePoint] = []
        points.reserveCapacity(sorted.count)
        for e in sorted {
            running += e.adjustment
            points.append(BalancePoint(id: e.id,
                                       date: e.date,
                                       balance: e.balance,
                                       adjusted: e.balance - running))
        }
        return points
    }

    static func maxBalance(_ entries: [StatsInput]) -> Double {
        entries.map(\.balance).max() ?? 0
    }

    /// Average balance over entries with date ≥ now − days.
    static func averageBalance(_ entries: [StatsInput], sinceDays days: Int,
                               now: Date = Date()) -> Double {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return 0 }
        let vals = entries.filter { $0.date >= cutoff }.map(\.balance)
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    static func totalDeposits(_ entries: [StatsInput]) -> Double {
        entries.map(\.adjustment).filter { $0 > 0 }.reduce(0, +)
    }

    static func totalWithdrawals(_ entries: [StatsInput]) -> Double {
        entries.map(\.adjustment).filter { $0 < 0 }.reduce(0, +)
    }

    /// Collapses multiple same-day snapshots to one representative per day
    /// (the last entry of that day, in stable input order) so boundary
    /// values like the starting balance are deterministic. Returns the
    /// representatives in ascending date order.
    static func dailyCollapsed(_ entries: [StatsInput]) -> [StatsInput] {
        let cal = Calendar.current
        let ordered = entries.enumerated().sorted {
            $0.element.date != $1.element.date
                ? $0.element.date < $1.element.date
                : $0.offset < $1.offset
        }.map(\.element)
        var byDay: [Date: StatsInput] = [:]
        var order: [Date] = []
        for e in ordered {
            let day = cal.startOfDay(for: e.date)
            if byDay[day] == nil { order.append(day) }
            byDay[day] = e        // keep last snapshot of the day
        }
        return order.map { byDay[$0]! }
    }

    static func summary(_ entries: [StatsInput]) -> PortfolioSummary {
        let daily = dailyCollapsed(entries)
        let start = daily.first?.balance ?? 0
        let current = daily.last?.balance ?? 0
        // Cash flows count every entry, not just the daily representatives.
        let netCashFlows = entries.map(\.adjustment).reduce(0, +)
        let gain = current - start - netCashFlows
        let denom = start + netCashFlows
        let pct = denom != 0 ? gain / denom : 0
        return PortfolioSummary(startingBalance: start,
                                netCashFlows: netCashFlows,
                                currentValue: current,
                                investmentGain: gain,
                                gainPercent: pct)
    }
}

// MARK: - TSX benchmark

struct TSXYearInput {
    let sortOrder: Int
    let year: Int
    let label: String?
    let tsxReturn: Double
    let netCashFlows: Double
    let actualStart: Double
    let actualEnd: Double

    var displayName: String {
        if let label, !label.isEmpty { return label }
        return String(year)
    }
}

struct TSXRow: Identifiable {
    let id = UUID()
    let input: TSXYearInput
    /// Chained simulated value of investing in the TSX with the same cash flows.
    let simulated: Double
}

struct TSXComparison {
    var startingBalance: (portfolio: Double, tsx: Double)
    var netCashFlows: (portfolio: Double, tsx: Double)
    var currentValue: (portfolio: Double, tsx: Double)
    var investmentGain: (portfolio: Double, tsx: Double)
    var gainPercent: (portfolio: Double, tsx: Double)
}

enum TSXModel {
    /// Chained simulation of investing in the index with the same cash flows,
    /// mirroring the source spreadsheet exactly: the first year establishes
    /// the baseline from its Actual Start, the second year re-bases to its own
    /// Actual Start (a quirk of the original sheet), and every later year
    /// compounds from the previous simulated value:
    ///   simulated = base × (1 + return) + cashFlows
    static func simulate(_ years: [TSXYearInput]) -> [TSXRow] {
        let ordered = years.sorted { $0.sortOrder < $1.sortOrder }
        var prev: Double?
        var rows: [TSXRow] = []
        for (i, y) in ordered.enumerated() {
            let base = (i < 2 || prev == nil) ? y.actualStart : prev!
            let sim = base * (1 + y.tsxReturn) + y.netCashFlows
            rows.append(TSXRow(input: y, simulated: sim))
            prev = sim
        }
        return rows
    }

    /// Builds the Your Portfolio vs TSX Equivalent vs Difference summary.
    /// The "Your Portfolio" column is supplied from the actual balance
    /// entries (the same source as the Dashboard) so the two tabs agree;
    /// the "TSX Equivalent" column is the self-consistent simulated benchmark
    /// derived from the yearly index data.
    static func comparison(years: [TSXYearInput], portfolio: PortfolioSummary) -> TSXComparison? {
        let ordered = years.sorted { $0.sortOrder < $1.sortOrder }
        guard let first = ordered.first else { return nil }
        let rows = simulate(ordered)
        let tsxStart = first.actualStart
        let tsxNetCF = ordered.map(\.netCashFlows).reduce(0, +)
        let tsxEnd = rows.last?.simulated ?? 0
        let tsxGain = tsxEnd - tsxStart - tsxNetCF
        let tsxDenom = tsxStart + tsxNetCF
        let tsxPct = tsxDenom != 0 ? tsxGain / tsxDenom : 0

        return TSXComparison(
            startingBalance: (portfolio.startingBalance, tsxStart),
            netCashFlows: (portfolio.netCashFlows, tsxNetCF),
            currentValue: (portfolio.currentValue, tsxEnd),
            investmentGain: (portfolio.investmentGain, tsxGain),
            gainPercent: (portfolio.gainPercent, tsxPct)
        )
    }
}
