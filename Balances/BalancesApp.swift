import AppKit
import SwiftUI

@main
struct BalancesApp: App {
    let persistence = PersistenceController.shared
    @State private var licensing = LicensingState()
    @Environment(\.openWindow) private var openWindow

    init() {
        let ctx = persistence.container.viewContext
        SeedImporter.seedIfNeeded(context: ctx)
        // Enable undo/redo only after first-launch seeding, so the bulk
        // seed import itself isn't sitting on the undo stack.
        let undo = UndoManager()
        undo.levelsOfUndo = 50
        ctx.undoManager = undo
        // Register App Intents phrases with Siri and Spotlight.
        BalancesShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(licensing)
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .frame(minWidth: 960, minHeight: 640)
        }
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("About Balances") { showAboutPanel() }
            }
            CommandGroup(after: .appInfo) {
                if !licensing.status.isLicensed {
                    Button("Enter License Key…") { openWindow(id: "license-entry") }
                }
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { performUndo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo") { performRedo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }

        // The Settings window and the license-entry window exist only to serve
        // licensing, so the App Store build ships without either. This is the
        // one place that has to branch at compile time rather than on
        // `Distribution.requiresLicense`: SceneBuilder does not accept a
        // runtime `if`.
        #if !APPSTORE
        Settings {
            SettingsLicenseView()
                .environment(licensing)
                .frame(width: 460)
        }

        Window("Enter License Key", id: "license-entry") {
            LicenseEntryView()
                .environment(licensing)
        }
        .windowResizability(.contentSize)
        #endif
    }

    private func performUndo() {
        let ctx = persistence.container.viewContext
        guard ctx.undoManager?.canUndo == true else { return }
        ctx.undoManager?.undo()
        ctx.saveLoggingErrors()
    }

    private func performRedo() {
        let ctx = persistence.container.viewContext
        guard ctx.undoManager?.canRedo == true else { return }
        ctx.undoManager?.redo()
        ctx.saveLoggingErrors()
    }

    /// Shows the standard "About Balances" panel with the current licensing status appended
    /// to the credits, so license info is visible without opening Settings.
    private func showAboutPanel() {
        let licenseText: String
        switch licensing.status {
        case .licensed(let info):
            let header = info.name.isEmpty ? "Licensed" : "Licensed to \(info.name)\n\(info.email)"
            licenseText = "\(header)\n\(expirationText(for: info))"
        case .trial(let daysLeft):
            licenseText = daysLeft == 1 ? "Trial: 1 day left" : "Trial: \(daysLeft) days left"
        case .blocked:
            licenseText = "Trial expired"
        case .unrestricted:
            // Nothing to say about licensing in an App Store build; show the
            // stock About panel.
            NSApp.orderFrontStandardAboutPanel(options: [:])
            return
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let credits = NSAttributedString(string: licenseText, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle,
        ])

        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    /// "Perpetual license" if `info.expiration` is nil, otherwise "Expires <date>".
    private func expirationText(for info: LicenseVerifier.LicenseInfo) -> String {
        guard let expiration = info.expiration else { return "Perpetual license" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Expires \(formatter.string(from: expiration))"
    }
}
