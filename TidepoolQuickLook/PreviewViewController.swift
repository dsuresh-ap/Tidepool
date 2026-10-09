import AppKit
import QuickLookUI
import SwiftUI
import WebKit

/// Shows a Mermaid diagram when you press Space on a `.mmd` file in Finder.
final class PreviewViewController: NSViewController, QLPreviewingController {
    private let renderer = DiagramRenderer()

    override func loadView() {
        view = NSHostingView(rootView: QuickLookPreview(renderer: renderer))
        preferredContentSize = NSSize(width: 800, height: 600)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let source = try MermaidDocument(data: Data(contentsOf: url)).text
        let isDark = view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        await renderer.render(source, theme: DiagramTheme.automatic.mermaidName(for: isDark ? .dark : .light))
    }
}

private struct QuickLookPreview: View {
    let renderer: DiagramRenderer

    var body: some View {
        WebView(renderer.page)
            .webViewContentBackground(.hidden)
            .overlay(alignment: .bottom) {
                if let message = renderer.errorMessage, renderer.svg == nil {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.monospaced())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                }
            }
    }
}
