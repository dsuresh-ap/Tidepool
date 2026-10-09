import Foundation
import UniformTypeIdentifiers
import Testing
@testable import Tidepool

struct MermaidErrorLocationTests {
    // Reported lines below are what Mermaid 12.1 returns for these sources.
    @Test(arguments: [
        ("flowchart LR\n    A --> B\n    B --> \n", 3, 3),
        ("---\ntitle: T\n---\nflowchart LR\n    A --> B\n    B --> \n", 3, 6),
        ("%%{init: {'theme':'dark'}}%%\nflowchart LR\n    A --> B\n    B --> \n", 3, 4),
        ("%% comment\n\nflowchart LR\n    A --> B\n    B --> \n", 3, 5),
        ("flowchart LR\n    A --> B\n    %% mid comment\n    B --> \n", 3, 4),
        ("flowchart LR\n    A --> B\n\n\n    B --> \n", 5, 5),
        ("\n\n  flowchart LR\n    A --> B\n    B --> \n", 3, 5),
    ])
    func mapsReportedLineToEditorLine(source: String, reported: Int, expected: Int) {
        #expect(MermaidErrorLocation.sourceLine(reported: reported, message: "", in: source) == expected)
    }

    @Test func readsLineFromNewerParserMessages() {
        let source = "---\ntitle: T\n---\n%% c\npie\n    \"A\" : 1\n    \"B\" 2\n"
        let message = "Parsing failed:  Parse error on line 3, column 9: Expecting token"
        #expect(MermaidErrorLocation.sourceLine(reported: nil, message: message, in: source) == 7)
    }

    @Test func pointsAtLastLineWhenErrorIsAtEnd() {
        #expect(MermaidErrorLocation.sourceLine(reported: 9, message: "", in: "pie\n  \"A\" : 1\n\n") == 2)
    }

    @Test func returnsNilWithoutALine() {
        #expect(MermaidErrorLocation.sourceLine(reported: nil, message: "No diagram type detected", in: "hello") == nil)
    }

    @Test func rewritesMessageLineNumbers() {
        #expect(MermaidErrorLocation.displayMessage("Parse error on line 5:\n...", line: 3) == "Parse error on line 3:\n...")
        #expect(MermaidErrorLocation.displayMessage("Parse error on line 3, column 9: x", line: 7) == "Parse error on line 7, column 9: x")
        #expect(MermaidErrorLocation.displayMessage("Unknown", line: nil) == "Unknown")
    }

    @Test(arguments: [
        ("---\ntitle: T\n---\nflowchart LR\n    A --> B\n    B --> C[Open\n    C --> D\n", 6),
        ("---\ntitle: T\n---\n%% c\npie\n    \"A\" : 1\n    \"B\" 2\n", 7),
        ("sequenceDiagram\n    %% note\n    A->>B: hi\n    A-->>\n", 4),
    ])
    func renderedErrorsPointAtTheEditorLine(source: String, expected: Int) async throws {
        let renderer = DiagramRenderer()
        await renderer.render(source, theme: "default")
        let message = try #require(renderer.errorMessage)
        #expect(MermaidErrorLocation.sourceLine(reported: renderer.reportedErrorLine, message: message, in: source) == expected)
    }
}

struct MermaidCompletionTests {
    @Test func suggestsDiagramTypesAtFirstStatement() {
        #expect(MermaidCompletion.suggestions(for: "seq", in: "seq", atFirstStatement: true) == ["sequenceDiagram"])
        #expect(MermaidCompletion.suggestions(for: "flow", in: "flow", atFirstStatement: true) == ["flowchart", "flowchart-elk"])
    }

    @Test func suggestsKeywordsForTheDiagramType() {
        let source = "flowchart LR\n    sub"
        #expect(MermaidCompletion.suggestions(for: "sub", in: source, atFirstStatement: false) == ["subgraph"])
        #expect(MermaidCompletion.suggestions(for: "par", in: "sequenceDiagram\n    par", atFirstStatement: false) == ["participant"])
    }

    @Test func suggestsNamesAlreadyInTheDiagram() {
        let source = "flowchart LR\n    Checkout --> Payment\n    Payment --> Che"
        #expect(MermaidCompletion.suggestions(for: "Che", in: source, atFirstStatement: false) == ["Checkout"])
        #expect(MermaidCompletion.suggestions(for: "pay", in: source, atFirstStatement: false) == ["Payment"])
    }

    @Test func leavesOutTheWordBeingTypedAndExactMatches() {
        let source = "flowchart LR\n    Unique"
        #expect(MermaidCompletion.suggestions(for: "Unique", in: source, atFirstStatement: false).isEmpty)
        #expect(MermaidCompletion.suggestions(for: "end", in: "flowchart LR\n  end", atFirstStatement: false).isEmpty)
        #expect(MermaidCompletion.suggestions(for: "", in: source, atFirstStatement: false).isEmpty)
    }
}

struct CodeEditorTests {
    @Test(arguments: [
        (1, NSRange(location: 0, length: 3)),
        (2, NSRange(location: 4, length: 5)),
        (3, NSRange(location: 10, length: 0)),
    ])
    func findsLineRanges(line: Int, expected: NSRange) {
        #expect(CodeEditor.Coordinator.range(ofLine: line, in: "pie\n  \"A\"\n") == expected)
    }

    @Test func returnsNilPastTheEnd() {
        #expect(CodeEditor.Coordinator.range(ofLine: 4, in: "a\nb") == nil)
    }
}

struct QuickLookExtensionTests {
    @Test func appEmbedsQuickLookExtensionForMermaidFiles() throws {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let bundle = try #require(Bundle(url: plugIns.appending(path: "TidepoolQuickLook.appex")))
        let attributes = try #require(
            (bundle.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionAttributes"] as? [String: Any]
        )
        #expect(attributes["QLSupportedContentTypes"] as? [String] == [UTType.mermaid.identifier])
        #expect(bundle.url(forResource: "mermaid.min", withExtension: "js") != nil)
    }
}
