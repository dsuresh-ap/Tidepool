import Testing
@testable import Tidepool

struct DiagramKindTests {
    @Test(arguments: DiagramKind.examples)
    func detectsEachExample(kind: DiagramKind) {
        #expect(DiagramKind.detect(in: kind.example) == kind)
    }

    @Test(arguments: [
        ("graph LR\nA-->B", DiagramKind.flowchart),
        ("graph TD;A-->B", .flowchart),
        ("stateDiagram\n[*] --> A", .state),
        ("classDiagram-v2\nclass A", .classDiagram),
        ("C4Context\ntitle System", .c4),
        ("sankey-beta\na,b,1", .sankey),
        ("  \n\tsequenceDiagram\n", .sequence),
    ])
    func detectsKeywords(source: String, expected: DiagramKind) {
        #expect(DiagramKind.detect(in: source) == expected)
    }

    @Test func skipsFrontMatterCommentsAndDirectives() {
        let source = """
            ---
            title: Checkout
            config:
              theme: forest
            ---
            %% A comment
            %%{init: {"theme": "dark"}}%%

            sequenceDiagram
                A->>B: Hi
            """
        #expect(DiagramKind.detect(in: source) == .sequence)
    }

    @Test(arguments: ["", "   \n", "%% only a comment", "hello world", "---\ntitle: x\n---\n"])
    func returnsNilWithoutAKnownDiagram(source: String) {
        #expect(DiagramKind.detect(in: source) == nil)
    }

    @Test func examplesHaveUniqueTitles() {
        let titles = DiagramKind.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
    }
}
