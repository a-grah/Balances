import SwiftUI

/// Body of the "License" pane in the app's Settings window (Cmd-,). Shows the current
/// licensing state and lets the user enter a key at any time.
struct SettingsLicenseView: View {
    @Environment(LicensingState.self) private var licensing

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Status") {
                statusRow
            }

            Button(licensing.status.isLicensed ? "Enter New License…" : "Enter License Key…") {
                openWindow(id: "license-entry")
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch licensing.status {
        case .licensed(let info):
            VStack(alignment: .leading, spacing: 4) {
                Label("Licensed", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                if !info.name.isEmpty {
                    Text("Licensed to: \(info.name)")
                }
                if !info.email.isEmpty {
                    Text(info.email)
                        .foregroundStyle(.secondary)
                }
                if let expiration = info.expiration {
                    Text("Expires \(expiration.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Perpetual license")
                        .foregroundStyle(.secondary)
                }
            }

        case .trial(let daysLeft):
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    daysLeft == 1 ? "Trial: 1 day left" : "Trial: \(daysLeft) days left",
                    systemImage: "clock"
                )
                Link("Purchase a license at store.bluepill.ca",
                     destination: LicensingState.purchaseURL)
                    .font(.callout)
            }

        case .blocked:
            VStack(alignment: .leading, spacing: 4) {
                Label("Trial expired", systemImage: "lock.fill")
                    .foregroundStyle(.red)
                Link("Purchase a license at store.bluepill.ca",
                     destination: LicensingState.purchaseURL)
                    .font(.callout)
            }
        }
    }
}
