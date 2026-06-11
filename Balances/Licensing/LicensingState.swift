import Foundation
import Observation

/// Observable licensing state for the app's root view to route on. There are exactly three
/// states: a valid license is present, a trial is in progress, or the trial has ended with no
/// valid license (hard block).
@Observable
final class LicensingState {
    enum Status: Equatable {
        case licensed(LicenseVerifier.LicenseInfo)
        case trial(daysLeft: Int)
        case blocked

        var isLicensed: Bool {
            if case .licensed = self { return true }
            return false
        }
    }

    private(set) var status: Status

    private let store: LicenseStore

    init(store: LicenseStore = LicenseStore()) {
        self.store = store
        self.status = .blocked
        refresh()
    }

    /// Re-derives `status` from scratch. A stored license token is always re-verified (its
    /// signature is checked again, never just a cached "isLicensed" flag); only if there is no
    /// valid license do we fall back to the trial bookkeeping.
    func refresh() {
        if let info = store.verifiedLicense() {
            status = .licensed(info)
            return
        }

        let now = Date()
        store.ensureTrialStarted(now: now)
        switch store.trialState(now: now) {
        case .active(let daysLeft):
            status = .trial(daysLeft: daysLeft)
        case .expired:
            status = .blocked
        }
    }

    /// Verifies `token` and, on success, persists it and refreshes `status` -- converting the
    /// app to `.licensed` (whether this happens during the trial or after it has expired).
    /// Nothing is written to the Keychain if verification fails.
    @discardableResult
    func submitLicense(_ token: String) -> Result<Void, LicenseVerifier.LicenseError> {
        switch LicenseVerifier.verify(token: token) {
        case .success:
            store.saveToken(token)
            refresh()
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
}
