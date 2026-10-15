import CoreData
import CryptoKit

extension NSManagedObject {
    /// Stable stand-in for a missing `id`. A bare `UUID()` fallback mints a different
    /// value on every access, so the same row would read as a new `Identifiable` on
    /// every render -- breaking chart diffing and table selection. Derived from the
    /// object ID instead, which is stable for a saved object.
    var derivedID: UUID {
        var bytes = Array(SHA256.hash(data: Data(objectID.uriRepresentation().absoluteString.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40   // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC 4122 variant
        return Data(bytes).withUnsafeBytes { UUID(uuid: $0.loadUnaligned(as: uuid_t.self)) }
    }
}

/// Bridges Core Data managed objects to the value-type inputs used by
/// the pure calculation layer in PortfolioStats.swift.
extension BalanceEntry {
    /// The row's own `id` when set, falling back to a stable derived one.
    var stableID: UUID { id ?? derivedID }

    var statsInput: StatsInput {
        StatsInput(id: stableID,
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
