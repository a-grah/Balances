import SwiftUI

@main
struct BalancesApp: App {
    let persistence = PersistenceController.shared
    @State private var updater = Updater.shared

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
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .frame(minWidth: 960, minHeight: 640)
        }
        .commands {
            SidebarCommands()
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { performUndo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo") { performRedo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .frame(width: 420)
        }
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
}
