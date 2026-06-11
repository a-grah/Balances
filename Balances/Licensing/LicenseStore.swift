import Foundation

/// Bridges Keychain-backed persistence with `LicenseVerifier`.
///
/// Two pieces of state live in the Keychain (not UserDefaults/plist, which a casual "delete
/// preferences" would wipe):
/// - `trialStart`: ISO-8601 timestamp of when the 14-day trial began.
/// - `licenseToken`: the raw PASETO token string, once a license has been entered.
///
/// Tamper note: keeping the trial start in the Keychain, plus treating any anomaly in that
/// record conservatively (see `trialState`), raises the bar for resetting a trial well above
/// "delete the app's prefs". None of this is tamper-proof -- a sufficiently motivated user can
/// still reset or forge their own Keychain entries. That's an accepted limitation of a fully
/// offline licensing model with no server to consult.
struct LicenseStore {
    private static let trialAccount = "trialStart"
    private static let tokenAccount = "licenseToken"
    private static let trialDurationDays = 14

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    enum TrialState: Equatable {
        case active(daysLeft: Int)
        case expired
    }

    var storedToken: String? {
        KeychainStore.read(account: Self.tokenAccount)
    }

    func saveToken(_ token: String) {
        KeychainStore.write(token, account: Self.tokenAccount)
    }

    /// Re-verifies the stored token (if any) against the embedded public key. Returns nil if
    /// there is no token or it fails verification for any reason -- the signature is always
    /// re-checked; a previously-valid token is never trusted on its own.
    func verifiedLicense() -> LicenseVerifier.LicenseInfo? {
        guard let token = storedToken else { return nil }
        guard case .success(let info) = LicenseVerifier.verify(token: token) else { return nil }
        return info
    }

    func trialStartDate() -> Date? {
        guard let raw = KeychainStore.read(account: Self.trialAccount) else { return nil }
        return Self.isoFormatter.date(from: raw)
    }

    /// Records the trial start time, but only if no record exists yet -- a trial can start at
    /// most once per Keychain. Safe to call on every launch.
    func ensureTrialStarted(now: Date) {
        guard KeychainStore.read(account: Self.trialAccount) == nil else { return }
        KeychainStore.write(Self.isoFormatter.string(from: now), account: Self.trialAccount)
    }

    /// Computes the trial state, treating any anomaly conservatively as `.expired` rather than
    /// granting extra trial time:
    /// - No record (e.g. `ensureTrialStarted` hasn't run yet) -> `.expired`.
    /// - A record that doesn't parse as a date (corrupted/tampered) -> `.expired`.
    /// - A record dated in the future (e.g. the system clock was turned back) -> `.expired`.
    /// - Otherwise, `.active(daysLeft:)` for up to `trialDurationDays` from the start date.
    func trialState(now: Date) -> TrialState {
        guard let raw = KeychainStore.read(account: Self.trialAccount) else { return .expired }
        guard let start = Self.isoFormatter.date(from: raw) else { return .expired }
        guard start <= now else { return .expired }

        let elapsedDays = Calendar(identifier: .gregorian)
            .dateComponents([.day], from: start, to: now).day ?? Self.trialDurationDays
        let daysLeft = Self.trialDurationDays - elapsedDays
        return daysLeft > 0 ? .active(daysLeft: daysLeft) : .expired
    }
}
