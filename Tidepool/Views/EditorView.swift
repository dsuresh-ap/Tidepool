import SwiftUI

/// One open diagram: Mermaid source on the left, live preview on the right.
struct EditorView: View {
    @Binding var text: String
    var fileName: String?

    @State private var renderer = DiagramRenderer()
    @State private var zoom = 1.0
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var pendingExample: DiagramKind?
    @AppStorage("theme") private var theme = DiagramTheme.automatic
    @Environment(\.colorScheme) private var colorScheme

    private static let zoomSteps = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]

    var body: some View {
        HSplitView {
            CodeEditor(text: $text)
                .frame(minWidth: 240, idealWidth: 380)
            PreviewPane(renderer: renderer, kind: DiagramKind.detect(in: text))
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar { toolbar }
        .task(id: RenderRequest(text: text, theme: theme.mermaidName(for: colorScheme))) {
            // Wait for a pause in typing, but show the first render at once.
            if renderer.svg != nil || renderer.errorMessage != nil {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            await renderer.render(text, theme: theme.mermaidName(for: colorScheme))
        }
        .onChange(of: zoom) { _, zoom in
            Task { await renderer.setZoom(zoom) }
        }
        .fileExporter(
            isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: (exportFile?.format ?? .png).contentType,
            defaultFilename: ExportFormat.baseFilename(from: fileName)
        ) { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("Could Not Export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
        } message: {
            Text(exportError ?? "")
        }
        .confirmationDialog(
            "Replace the current diagram?",
            isPresented: Binding(get: { pendingExample != nil }, set: { if !$0 { pendingExample = nil } }),
            presenting: pendingExample
        ) { kind in
            Button("Replace with \(kind.title)", role: .destructive) { text = kind.example }
        } message: { _ in
            Text("You can undo this change.")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem {
            Menu("Examples", systemImage: "square.grid.2x2") {
                ForEach(DiagramKind.examples) { kind in
                    Button(kind.title, systemImage: kind.systemImage) { insert(kind) }
                }
            }
            .help("Start from an example diagram")
        }
        ToolbarItemGroup {
            Button("Zoom Out", systemImage: "minus.magnifyingglass") { stepZoom(by: -1) }
                .disabled(zoom <= Self.zoomSteps.first!)
            Button("Actual Size", systemImage: "1.magnifyingglass") { zoom = 1 }
                .disabled(zoom == 1)
            Button("Zoom In", systemImage: "plus.magnifyingglass") { stepZoom(by: 1) }
                .disabled(zoom >= Self.zoomSteps.last!)
        }
        ToolbarItem {
            Picker("Theme", systemImage: "paintpalette", selection: $theme) {
                ForEach(DiagramTheme.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .help("Diagram theme")
        }
        ToolbarItem {
            Menu("Export", systemImage: "square.and.arrow.up") {
                ForEach(ExportFormat.allCases) { format in
                    Button("\(format.title)…") { export(format) }
                }
            }
            .disabled(renderer.svg == nil)
            .help("Export the diagram as SVG, PNG, or PDF")
            .accessibilityIdentifier("exportMenu")
        }
    }

    private func insert(_ kind: DiagramKind) {
        let isUnchanged = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || DiagramKind.allCases.contains { $0.example == text }
        if isUnchanged { text = kind.example } else { pendingExample = kind }
    }

    private func stepZoom(by step: Int) {
        let index = Self.zoomSteps.firstIndex { $0 >= zoom } ?? Self.zoomSteps.count - 1
        zoom = Self.zoomSteps[min(max(index + step, 0), Self.zoomSteps.count - 1)]
    }

    private func export(_ format: ExportFormat) {
        Task {
            do {
                let data = try await renderer.export(format, background: theme.exportBackground(for: colorScheme))
                exportFile = ExportFile(data: data, format: format)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }
}

private struct RenderRequest: Equatable {
    var text: String
    var theme: String
}
