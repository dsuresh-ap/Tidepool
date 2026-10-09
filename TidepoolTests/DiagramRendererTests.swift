import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Tidepool

@Suite(.serialized)
struct DiagramRendererTests {
    private let flowchart = "flowchart LR\n    A[Start] --> B[End]"

    @Test func inliningEscapesClosingScriptTags() {
        let html = DiagramRenderer.inlinePreview(
            template: "<script nonce=\"{{NONCE}}\">{{MERMAID}}</script>",
            script: "let s = '</SCRIPT><b>';",
            nonce: "abc"
        )
        #expect(html == "<script nonce=\"abc\">let s = '<\\/script><b>';</script>")
    }

    @Test func previewHTMLInlinesMermaid() throws {
        let html = try DiagramRenderer.previewHTML()
        #expect(!html.contains("{{MERMAID}}"))
        #expect(!html.contains("{{NONCE}}"))
        #expect(html.contains("globalThis[\"mermaid\"]"))
    }

    @Test func rendersValidSource() async {
        let renderer = DiagramRenderer()
        await renderer.render(flowchart, theme: "default")
        #expect(renderer.errorMessage == nil)
        #expect(renderer.svg?.contains("<svg") == true)
        #expect(renderer.svg?.contains("Start") == true)
    }

    @Test func reportsErrorsAndKeepsLastGoodDiagram() async throws {
        let renderer = DiagramRenderer()
        await renderer.render(flowchart, theme: "default")
        let good = try #require(renderer.svg)

        await renderer.render("flowchart LR\n    A --> ", theme: "default")
        #expect(renderer.errorMessage?.isEmpty == false)
        #expect(renderer.svg == good)

        await renderer.render(flowchart, theme: "default")
        #expect(renderer.errorMessage == nil)
    }

    @Test func emptySourceClearsPreview() async {
        let renderer = DiagramRenderer()
        await renderer.render(flowchart, theme: "default")
        await renderer.render("  \n", theme: "default")
        #expect(renderer.svg == nil)
        #expect(renderer.errorMessage == nil)
    }

    @Test(arguments: DiagramKind.examples)
    func everyExampleRenders(kind: DiagramKind) async {
        let renderer = DiagramRenderer()
        await renderer.render(kind.example, theme: "dark")
        #expect(renderer.errorMessage == nil, "\(kind.title): \(renderer.errorMessage ?? "")")
        #expect(renderer.svg != nil)
    }

    @Test func exportFailsWithoutDiagram() async {
        let renderer = DiagramRenderer()
        await renderer.render("not mermaid", theme: "default")
        await #expect(throws: DiagramRenderer.RenderError.self) {
            try await renderer.export(.png, background: "#ffffff")
        }
    }

    @Test func exportsStandaloneSVG() async throws {
        let renderer = DiagramRenderer()
        await renderer.render(flowchart, theme: "default")
        let data = try await renderer.export(.svg, background: "#ffffff")
        let svg = try #require(String(data: data, encoding: .utf8))
        #expect(svg.hasPrefix("<?xml"))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(svg.contains("background-color"))
        #expect(!svg.contains("foreignObject"), "Labels must be SVG text so other apps can show them")
        #expect(XMLParser(data: data).parse(), "Exported SVG must be well-formed XML")
    }

    @Test func exportsRetinaPNG() async throws {
        let renderer = DiagramRenderer()
        await renderer.render(flowchart, theme: "default")
        let svgData = try await renderer.export(.svg, background: "#ffffff")
        let data = try await renderer.export(.png, background: "#ffffff")

        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let width = try #require(Self.svgWidth(svgData))
        #expect(image.width == Int((width * 2).rounded()))
    }

    @Test func exportsVectorPDF() async throws {
        let renderer = DiagramRenderer()
        await renderer.render(flowchart, theme: "default")
        let svgData = try await renderer.export(.svg, background: "#ffffff")
        let data = try await renderer.export(.pdf, background: "#ffffff")

        #expect(data.starts(with: Array("%PDF".utf8)))
        let pdf = try #require(CGDataProvider(data: data as CFData).flatMap(CGPDFDocument.init))
        #expect(pdf.numberOfPages == 1)
        let box = try #require(pdf.page(at: 1)?.getBoxRect(.mediaBox))
        let width = try #require(Self.svgWidth(svgData))
        #expect(abs(box.width - width) <= 1)
    }

    private static func svgWidth(_ data: Data) -> Double? {
        let svg = String(decoding: data, as: UTF8.self)
        guard let match = svg.firstMatch(of: /<svg[^>]*\swidth="([\d.]+)"/) else { return nil }
        return Double(match.1)
    }
}
