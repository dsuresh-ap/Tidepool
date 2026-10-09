import SwiftUI
import WebKit

/// The rendered diagram, with the diagram type and any Mermaid error below it.
struct PreviewPane: View {
    let renderer: DiagramRenderer
    let kind: DiagramKind?
    var isEmpty = false

    var body: some View {
        WebView(renderer.page)
            .overlay {
                if isEmpty {
                    ContentUnavailableView(
                        "No Diagram",
                        systemImage: "point.3.connected.trianglepath.dotted",
                        description: Text("Type Mermaid code, or choose a diagram from Examples.")
                    )
                }
            }
            .webViewContentBackground(.hidden)
            .webViewMagnificationGestures(.enabled)
            .webViewLinkPreviews(.disabled)
            .accessibilityIdentifier("preview")
            .safeAreaInset(edge: .bottom, spacing: 0) { statusBar }
    }

    @ViewBuilder private var statusBar: some View {
        if let message = renderer.errorMessage {
            Label {
                Text(message)
                    .font(.callout.monospaced())
                    .lineLimit(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .padding(10)
            .background(.regularMaterial)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("renderError")
        } else if let kind {
            Text(kind.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("diagramKind")
        }
    }
}
