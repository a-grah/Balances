import SwiftUI

/// Routes the app's window content based on `LicensingState`:
/// - `.licensed` / `.unrestricted` -> the normal app UI.
/// - `.trial` -> the normal app UI with an unobtrusive trial banner.
/// - `.blocked` -> a non-dismissable licensing screen, replacing the entire UI.
///
/// App Store builds are always `.unrestricted`, so only the first branch is
/// ever reachable there (see `Distribution`).
struct RootView: View {
    @Environment(LicensingState.self) private var licensing
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        switch licensing.status {
        case .licensed, .unrestricted:
            ContentView()

        case .trial(let daysLeft):
            ContentView()
                .safeAreaInset(edge: .bottom) {
                    trialBanner(daysLeft: daysLeft)
                }

        case .blocked:
            LicensingGateView()
        }
    }

    private func trialBanner(daysLeft: Int) -> some View {
        HStack {
            Text(daysLeft == 1 ? "Trial: 1 day left" : "Trial: \(daysLeft) days left")
                .foregroundStyle(.secondary)
            Spacer()
            Link("Purchase…", destination: LicensingState.purchaseURL)
            Button("Activate…") { openWindow(id: "license-entry") }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
