import SwiftUI

/// Non-dismissable screen shown when the trial has ended with no valid license. `RootView`
/// shows this *instead of* `ContentView` (a full replacement, not a sheet or overlay), so
/// there is no way to dismiss it short of entering a valid license.
struct LicensingGateView: View {
    @Environment(LicensingState.self) private var licensing

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Your Balances trial has ended")
                    .font(.title2)
                    .bold()
                Text("Enter a license key below to continue using Balances.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            LicenseEntryControls { token in
                switch licensing.submitLicense(token) {
                case .success: return nil
                case .failure(let error): return error
                }
            }
            .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(minWidth: 480, minHeight: 360)
    }
}
