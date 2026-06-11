import SwiftUI
import UniformTypeIdentifiers

/// Shared license-entry UI: a multiline paste field plus a "Load license file…" button, both
/// feeding the same `submit` closure. Used by both the blocking license gate and the Settings
/// License pane.
struct LicenseEntryControls: View {
    /// Verifies (and, on success, persists) `token`. Returns nil on success, or an error to
    /// display to the user.
    let submit: (_ token: String) -> LicenseVerifier.LicenseError?

    @State private var tokenText = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste your license key:")
                .font(.headline)

            TextEditor(text: $tokenText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Load license file…") { loadFromFile() }

                Spacer()

                Button("Activate") { activate(tokenText) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(tokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func activate(_ token: String) {
        errorMessage = submit(token)?.userMessage
    }

    private func loadFromFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        var allowedTypes: [UTType] = [.plainText, .text]
        if let licenseType = UTType(filenameExtension: "license") { allowedTypes.append(licenseType) }
        if let pasetoType = UTType(filenameExtension: "paseto") { allowedTypes.append(pasetoType) }
        panel.allowedContentTypes = allowedTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            tokenText = contents
            activate(contents)
        } catch {
            errorMessage = "Couldn't read that file."
        }
    }
}
