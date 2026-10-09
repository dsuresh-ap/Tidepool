import SwiftUI

@main
struct TidepoolApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MermaidDocument()) { file in
            EditorView(
                text: file.$document.text,
                fileName: file.fileURL?.deletingPathExtension().lastPathComponent
            )
            .background(WindowTabbing())
        }
        .defaultSize(width: 1100, height: 700)
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
