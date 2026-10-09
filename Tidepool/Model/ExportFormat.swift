import SwiftUI
import UniformTypeIdentifiers

/// File types a diagram can be exported to.
enum ExportFormat: String, CaseIterable, Identifiable {
    /// Vector image for the web, Figma, and editors.
    case svg
    /// Raster image for chat, slides, and documents.
    case png
    /// Vector document for print and sharing.
    case pdf

    var id: Self { self }

    var title: String {
        switch self {
        case .svg: "SVG Image"
        case .png: "PNG Image"
        case .pdf: "PDF Document"
        }
    }

    var contentType: UTType {
        switch self {
        case .svg: .svg
        case .png: .png
        case .pdf: .pdf
        }
    }

    /// Makes a safe file name (without extension) from a document name.
    static func baseFilename(from name: String?) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters)
        let cleaned = (name ?? "")
            .components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "Diagram" : cleaned
    }
}

/// An exported file, ready for `fileExporter`.
struct ExportFile: FileDocument {
    static let readableContentTypes = ExportFormat.allCases.map(\.contentType)

    var data: Data
    var format: ExportFormat

    init(data: Data, format: ExportFormat) {
        self.data = data
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
