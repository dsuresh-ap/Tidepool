import AppKit
import SwiftUI

/// One open diagram: Mermaid source on the left, live preview on the right.
struct EditorView: View {
    @Binding var text: String
    var fileURL: URL?

    @State private var renderer = DiagramRenderer()
    @State private var zoom = 1.0
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var pendingExample: DiagramKind?
    @State private var confirmation: String?
    @AppStorage("theme") private var theme = DiagramTheme.automatic
    @AppStorage("showsSource") private var showsSource = true
    @Environment(\.colorScheme) private var colorScheme

    private static let zoomSteps = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]

    var body: some View {
        HSplitView {
            if showsSource {
                CodeEditor(text: $text)
                    .frame(minWidth: 240, idealWidth: 380)
            }
            PreviewPane(renderer: renderer, kind: DiagramKind.detect(in: text), isEmpty: isEmpty)
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) { confirmationBadge }
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
        .task(id: fileURL) { await reloadWhenFileChanges() }
        .onChange(of: zoom) { _, zoom in
            Task { await renderer.setZoom(zoom) }
        }
        .fileExporter(
            isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: (exportFile?.format ?? .png).contentType,
            defaultFilename: ExportFormat.baseFilename(from: fileURL?.deletingPathExtension().lastPathComponent)
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

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(showsSource ? "Hide Source" : "Show Source", systemImage: "sidebar.left") {
                withAnimation(.snappy(duration: 0.2)) { showsSource.toggle() }
            }
            .keyboardShortcut("s", modifiers: [.control, .command])
            .help(showsSource ? "Hide the Mermaid source (⌃⌘S)" : "Show the Mermaid source (⌃⌘S)")
            .accessibilityIdentifier("sourceToggle")
        }
        ToolbarItem {
            Menu("Examples", systemImage: "square.grid.2x2") {
                ForEach(DiagramKind.examples) { kind in
                    Button(kind.title, systemImage: kind.systemImage) { insert(kind) }
                }
            }
            .help("Start from an example diagram")
        }
        ToolbarItem {
            ControlGroup {
                Button("Zoom Out", systemImage: "minus") { stepZoom(by: -1) }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(zoom <= Self.zoomSteps.first!)
                Button { zoom = 1 } label: {
                    Text(zoom == 1 ? "Fit" : zoom.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                        .frame(minWidth: 36)
                }
                .keyboardShortcut("0", modifiers: .command)
                .help("Fit the diagram to the window (⌘0)")
                .accessibilityLabel("Zoom to Fit")
                .accessibilityValue(zoom == 1 ? "Fit" : zoom.formatted(.percent))
                Button("Zoom In", systemImage: "plus") { stepZoom(by: 1) }
                    .keyboardShortcut("=", modifiers: .command)
                    .disabled(zoom >= Self.zoomSteps.last!)
            } label: {
                Label("Zoom", systemImage: "plus.magnifyingglass")
            }
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
                Section("Save As") {
                    ForEach(ExportFormat.allCases) { format in
                        Button("\(format.title)…") { export(format) }
                    }
                }
                Section("Copy") {
                    Button("Copy Image", systemImage: "photo") { copyImage() }
                    Button("Copy as Markdown", systemImage: "text.badge.checkmark") { copyMarkdown() }
                }
            }
            .disabled(renderer.svg == nil)
            .help("Save or copy the diagram")
            .accessibilityIdentifier("exportMenu")
        }
    }

    @ViewBuilder private var confirmationBadge: some View {
        if let confirmation {
            Label(confirmation, systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect()
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("confirmation")
        }
    }

    /// Shows changes that another app writes to the file, such as a script that regenerates the
    /// diagram. Unsaved edits in this window win: the file is reloaded only when there are none.
    private func reloadWhenFileChanges() async {
        guard let fileURL else { return }
        var diskText = text
        for await _ in FileChanges.stream(for: fileURL) {
            guard let data = try? Data(contentsOf: fileURL),
                  let latest = try? MermaidDocument(data: data).text,
                  latest != diskText
            else { continue }
            if let document = NSDocumentController.shared.document(for: fileURL), let type = document.fileType {
                // Reverting reads the file through the document, so the window does not show "Edited".
                if !document.isDocumentEdited { try? document.revert(toContentsOf: fileURL, ofType: type) }
            } else if text == diskText {
                text = latest
            }
            diskText = latest
        }
    }

    private func insert(_ kind: DiagramKind) {
        let isUnchanged = isEmpty || DiagramKind.allCases.contains { $0.example == text }
        if isUnchanged { text = kind.example } else { pendingExample = kind }
    }

    private func stepZoom(by step: Int) {
        let index = Self.zoomSteps.firstIndex { $0 >= zoom } ?? Self.zoomSteps.count - 1
        zoom = Self.zoomSteps[min(max(index + step, 0), Self.zoomSteps.count - 1)]
    }

    private var exportBackground: String { theme.exportBackground(for: colorScheme) }

    private func export(_ format: ExportFormat) {
        Task {
            do {
                exportFile = ExportFile(data: try await renderer.export(format, background: exportBackground), format: format)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private func copyImage() {
        Task {
            do {
                let png = try await renderer.export(.png, background: exportBackground)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setData(png, forType: .png)
                confirm("Copied image")
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private func copyMarkdown() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(MermaidSource.markdown(for: text), forType: .string)
        confirm("Copied as Markdown")
    }

    private func confirm(_ message: String) {
        withAnimation(.snappy) { confirmation = message }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.snappy) { if confirmation == message { confirmation = nil } }
        }
    }
}

private struct RenderRequest: Equatable {
    var text: String
    var theme: String
}
