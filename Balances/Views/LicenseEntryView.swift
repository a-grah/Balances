import SwiftUI

/// Content of the standalone "Enter License Key" window, opened from the app menu or the
/// trial banner. Closes itself on a successful activation.
struct LicenseEntryView: View {
    @Environment(LicensingState.self) private var licensing
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(licensing.status.isLicensed ? "Enter New License" : "Enter License Key")
                .font(.title2)
                .bold()

            LicenseEntryControls { token in
                switch licensing.submitLicense(token) {
                case .success:
                    dismissWindow()
                    return nil
                case .failure(let error):
                    return error
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
