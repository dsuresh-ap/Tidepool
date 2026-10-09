import SwiftUI

@main
struct TidepoolApp: App {
    init() {
        // When the app hosts unit tests, keep it in the background so it does not take focus.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            NSApplication.shared.setActivationPolicy(.prohibited)
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: MermaidDocument()) { file in
            EditorView(text: file.$document.text, fileURL: file.fileURL)
            .background(WindowTabbing())
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) { NewFromClipboardButton() }
        }
    }
}

/// Makes a diagram from copied Mermaid code, such as a code block in a chat reply or a terminal.
private struct NewFromClipboardButton: View {
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Button("New Diagram from Clipboard") {
            let text = NSPasteboard.general.string(forType: .string) ?? ""
            newDocument(MermaidDocument(text: MermaidSource.extract(from: text)))
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}

/// Opens each document as a tab in the frontmost window, like Safari or Xcode.
/// People can drag a tab out to its own window, or tile two windows side by side.
private struct WindowTabbing: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { TabbingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class TabbingView: NSView {
        override func viewWillMove(toWindow window: NSWindow?) {
            super.viewWillMove(toWindow: window)
            window?.tabbingMode = .preferred
        }
    }
}
