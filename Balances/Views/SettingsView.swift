import SwiftUI

struct SettingsView: View {
    @State private var updater = Updater.shared

    var body: some View {
        Form {
            Section {
                Toggle("Check for updates automatically", isOn: $updater.checksAutomatically)
                    .disabled(!updater.isAvailable)
                Button("Check Now") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            } header: {
                Text("Updates")
            }
        }
        .formStyle(.grouped)
    }
}
