import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Mermaid source files (`.mmd`, `.mermaid`).
    static let mermaid = UTType(exportedAs: "io.github.dsuresh-ap.tidepool.mermaid", conformingTo: .plainText)
}

/// A Mermaid source file.
struct MermaidDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.mermaid, .plainText]
    static let writableContentTypes: [UTType] = [.mermaid]

    var text: String

    init(text: String = DiagramKind.flowchart.example) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try self.init(data: data)
    }

    init(data: Data) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        // Drop a UTF-8 byte order mark so that diagram detection sees the first keyword.
        self.text = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
