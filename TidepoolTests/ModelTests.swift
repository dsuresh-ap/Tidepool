import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import Tidepool

struct DiagramThemeTests {
    @Test func automaticFollowsColorScheme() {
        #expect(DiagramTheme.automatic.mermaidName(for: .light) == "default")
        #expect(DiagramTheme.automatic.mermaidName(for: .dark) == "dark")
    }

    @Test func explicitThemesIgnoreColorScheme() {
        #expect(DiagramTheme.forest.mermaidName(for: .dark) == "forest")
        #expect(DiagramTheme.dark.mermaidName(for: .light) == "dark")
        #expect(DiagramTheme.default.mermaidName(for: .dark) == "default")
    }

    @Test func exportBackgroundMatchesTheme() {
        #expect(DiagramTheme.dark.exportBackground(for: .light) == "#1e1e1e")
        #expect(DiagramTheme.neutral.exportBackground(for: .dark) == "#ffffff")
        #expect(DiagramTheme.automatic.exportBackground(for: .dark) == "#1e1e1e")
    }
}

struct ExportFormatTests {
    @Test func contentTypes() {
        #expect(ExportFormat.svg.contentType == .svg)
        #expect(ExportFormat.png.contentType == .png)
        #expect(ExportFormat.pdf.contentType == .pdf)
        #expect(ExportFile.readableContentTypes == [.svg, .png, .pdf])
    }

    @Test(arguments: [
        (nil as String?, "Diagram"),
        ("", "Diagram"),
        ("   ", "Diagram"),
        ("Checkout Flow", "Checkout Flow"),
        ("a/b:c", "a-b-c"),
        (".hidden.", "hidden"),
        ("tab\there", "tab-here"),
    ])
    func baseFilename(name: String?, expected: String) {
        #expect(ExportFormat.baseFilename(from: name) == expected)
    }
}

struct MermaidDocumentTests {
    @Test func newDocumentStartsWithFlowchartExample() {
        #expect(MermaidDocument().text == DiagramKind.flowchart.example)
    }

    @Test func readsUTF8AndDropsByteOrderMark() throws {
        let document = try MermaidDocument(data: Data("\u{FEFF}pie\n\"A\" : 1".utf8))
        #expect(document.text == "pie\n\"A\" : 1")
        #expect(DiagramKind.detect(in: document.text) == .pie)
    }

    @Test func rejectsInvalidUTF8() {
        #expect(throws: CocoaError.self) { try MermaidDocument(data: Data([0xFF, 0xFE, 0xFD])) }
    }

    @Test func mermaidTypeUsesMmdExtension() {
        #expect(UTType.mermaid.preferredFilenameExtension == "mmd")
        #expect(UTType.mermaid.conforms(to: .plainText))
        #expect(UTType(filenameExtension: "mermaid") == .mermaid)
    }
}
