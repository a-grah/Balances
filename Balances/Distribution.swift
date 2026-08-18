import Foundation

/// Which channel this build ships through.
///
/// Everything that differs between the App Store build and the direct download
/// from bluepill.ca routes through here, so the differences stay enumerable in
/// one file instead of spreading as `#if APPSTORE` blocks across the UI. The
/// flag is set per-target: the "Balances (App Store)" target defines `APPSTORE`
/// in its Swift compilation conditions.
enum Distribution {
    enum Channel {
        case direct
        case appStore
    }

    #if APPSTORE
    static let channel: Channel = .appStore
    #else
    static let channel: Channel = .direct
    #endif

    /// Whether the app gates itself behind a trial and license key.
    ///
    /// The App Store build is unlocked outright — Apple handles the purchase,
    /// and a separate license-key flow inside a paid app is grounds for
    /// rejection (and would double-charge the user besides).
    static var requiresLicense: Bool { channel == .direct }
}
