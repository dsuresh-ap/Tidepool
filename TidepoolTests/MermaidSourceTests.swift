import Foundation
import Testing
@testable import Tidepool

struct MermaidSourceTests {
    @Test func extractsFirstMermaidBlockFromMarkdown() {
        let reply = """
            Here is the diagram:

            ```mermaid
            flowchart LR
                A --> B
            ```

            ```mermaid
            pie
            ```
            """
        #expect(MermaidSource.extract(from: reply) == "flowchart LR\n    A --> B")
    }

    @Test func extractsTildeFences() {
        #expect(MermaidSource.extract(from: "~~~mermaid\ngantt\n~~~") == "gantt")
    }

    @Test func returnsPlainSourceTrimmed() {
        #expect(MermaidSource.extract(from: "\n  sequenceDiagram\n  A->>B: Hi\n\n") == "sequenceDiagram\n  A->>B: Hi")
    }

    @Test func ignoresOtherCodeBlocks() {
        #expect(MermaidSource.extract(from: "```swift\nlet a = 1\n```") == "```swift\nlet a = 1\n```")
    }

    @Test func markdownRoundTrips() {
        let source = "flowchart TD\n    A --> B\n"
        let markdown = MermaidSource.markdown(for: source)
        #expect(markdown == "```mermaid\nflowchart TD\n    A --> B\n```\n")
        #expect(MermaidSource.extract(from: markdown) == "flowchart TD\n    A --> B")
    }
}

struct MermaidSyntaxTests {
    private func tokens(_ source: String) -> [(String, MermaidSyntax.Token)] {
        MermaidSyntax.tokens(in: source).map { ((source as NSString).substring(with: $0.range), $0.token) }
    }

    @Test func colorsKeywordArrowsStringsAndComments() {
        let result = tokens("flowchart LR\n  %% note --> here\n  A[\"x --> y\"] --> B")
        #expect(result.map(\.0) == ["flowchart", "%% note --> here", "\"x --> y\"", "-->"])
        #expect(result.map(\.1) == [.keyword, .comment, .string, .arrow])
    }

    @Test(arguments: ["-->", "---", "==>", "-.->", "--x", "--o", "<-->", "~~~", "->>", "-->>", "-)", "--)"])
    func recognizesArrows(arrow: String) {
        #expect(tokens("A \(arrow) B").map(\.0) == [arrow])
    }

    @Test(arguments: ["stateDiagram-v2", "x-axis Low", "2026-01-05", "box-xl"])
    func ignoresHyphensInWords(text: String) {
        #expect(tokens("  \(text)").allSatisfy { $0.1 != .arrow })
    }

    @Test func treatsFrontMatterAsComment() {
        let result = tokens("---\ntitle: Demo\n---\npie\n  \"A\" : 1")
        #expect(result.first?.0 == "---\ntitle: Demo\n---")
        #expect(result.first?.1 == .comment)
        #expect(result.contains { $0 == ("pie", .keyword) })
    }

    @Test func doesNotColorUnknownFirstWord() {
        #expect(tokens("hello world").isEmpty)
    }

    @Test func rangesUseUTF16Offsets() {
        let source = "flowchart LR\n  🌊[\"Tide\"] --> B"
        let arrow = MermaidSyntax.tokens(in: source).first { $0.token == .arrow }
        #expect(arrow.map { (source as NSString).substring(with: $0.range) } == "-->")
    }
}

@Suite(.serialized)
struct FileChangesTests {
    @Test func reportsInPlaceWritesAndAtomicReplacements() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mmd")
        try "pie\n".write(to: url, atomically: false, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        final class Counter { var value = 0 }
        let changes = Counter()
        let watching = Task { for await _ in FileChanges.stream(for: url) { changes.value += 1 } }
        defer { watching.cancel() }
        try await Task.sleep(for: .milliseconds(200))

        func changeIsReported(by write: () throws -> Void) async throws -> Bool {
            let before = changes.value
            try write()
            for _ in 0..<30 where changes.value == before { try await Task.sleep(for: .milliseconds(100)) }
            try await Task.sleep(for: .milliseconds(200))
            return changes.value > before
        }

        #expect(try await changeIsReported {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("\"A\" : 1\n".utf8))
            try handle.close()
        })
        #expect(try await changeIsReported { try "gantt\n".write(to: url, atomically: true, encoding: .utf8) })
        #expect(try await changeIsReported { try "timeline\n".write(to: url, atomically: true, encoding: .utf8) },
                "The watcher must follow the file after an atomic replace")
    }
}
