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

    static func summary(_ entries: [StatsInput]) -> PortfolioSummary {
        let sorted = entries.sorted { $0.date < $1.date }
        let start = sorted.first?.balance ?? 0
        let current = sorted.last?.balance ?? 0
        let netCashFlows = sorted.map(\.adjustment).reduce(0, +)
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
    /// Year 1: start × (1 + return) + cashFlows.
    /// Later years: prevSimulated × (1 + return) + cashFlows.
    static func simulate(_ years: [TSXYearInput]) -> [TSXRow] {
        let ordered = years.sorted { $0.sortOrder < $1.sortOrder }
        var prev: Double?
        var rows: [TSXRow] = []
        for y in ordered {
            let base = prev ?? y.actualStart
            let sim = base * (1 + y.tsxReturn) + y.netCashFlows
            rows.append(TSXRow(input: y, simulated: sim))
            prev = sim
        }
        return rows
    }

    static func comparison(_ years: [TSXYearInput]) -> TSXComparison? {
        let ordered = years.sorted { $0.sortOrder < $1.sortOrder }
        guard let first = ordered.first, let last = ordered.last else { return nil }
        let rows = simulate(ordered)
        let start = first.actualStart
        let netCF = ordered.map(\.netCashFlows).reduce(0, +)
        let portfolioEnd = last.actualEnd
        let tsxEnd = rows.last?.simulated ?? 0

        func gain(end: Double) -> Double { end - start - netCF }
        func pct(_ g: Double) -> Double {
            let denom = start + netCF
            return denom != 0 ? g / denom : 0
        }
        let pGain = gain(end: portfolioEnd)
        let tGain = gain(end: tsxEnd)
        return TSXComparison(
            startingBalance: (start, start),
            netCashFlows: (netCF, netCF),
            currentValue: (portfolioEnd, tsxEnd),
            investmentGain: (pGain, tGain),
            gainPercent: (pct(pGain), pct(tGain))
        )
    }
}
