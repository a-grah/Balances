import AppKit
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
        /// This build does no licensing at all (App Store) — the app is simply
        /// unlocked, with no trial clock and no key to enter.
        case unrestricted

        var isLicensed: Bool {
            switch self {
            case .licensed, .unrestricted: return true
            case .trial, .blocked: return false
            }
        }
    }

    /// Where users can buy a license; surfaced wherever the app is in a trial or blocked state.
    static let purchaseURL = URL(string: "https://store.bluepill.ca/products/Balances%20Portfolio%20Tracker")!

    private(set) var status: Status

    private let store: LicenseStore

    @ObservationIgnored private var clockObservers: [NSObjectProtocol] = []

    init(store: LicenseStore = LicenseStore()) {
        self.store = store
        self.status = .blocked
        refresh()
        observeClockChanges()
    }

    deinit {
        clockObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Licenses expire and trials roll over on a date boundary, so a session left running
    /// overnight (or asleep) would otherwise keep showing yesterday's status until relaunch.
    /// App Store builds have no clock to watch.
    private func observeClockChanges() {
        guard Distribution.requiresLicense else { return }
        let center = NotificationCenter.default
        for name in [Notification.Name.NSCalendarDayChanged, NSApplication.didBecomeActiveNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
            clockObservers.append(token)
        }
    }

    /// Re-derives `status` from scratch. A stored license token is always re-verified (its
    /// signature is checked again, never just a cached "isLicensed" flag); only if there is no
    /// valid license do we fall back to the trial bookkeeping.
    func refresh() {
        // App Store builds never touch the Keychain or start a trial clock:
        // there is nothing to verify and nothing to expire.
        guard Distribution.requiresLicense else {
            status = .unrestricted
            return
        }

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
