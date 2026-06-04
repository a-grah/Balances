import Foundation

/// Time windows for the dashboard balance chart.
enum DateRange: String, CaseIterable, Identifiable {
    case month1 = "1M"
    case month3 = "3M"
    case month6 = "6M"
    case year1 = "1Y"
    case year5 = "5Y"
    case all = "All"

    var id: String { rawValue }

    /// Earliest date to include, or nil for "all time".
    func startDate(from now: Date = Date()) -> Date? {
        let cal = Calendar.current
        switch self {
        case .month1: return cal.date(byAdding: .month, value: -1, to: now)
        case .month3: return cal.date(byAdding: .month, value: -3, to: now)
        case .month6: return cal.date(byAdding: .month, value: -6, to: now)
        case .year1:  return cal.date(byAdding: .year, value: -1, to: now)
        case .year5:  return cal.date(byAdding: .year, value: -5, to: now)
        case .all:    return nil
        }
    }
}
