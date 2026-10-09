import Foundation
import WebKit

/// Turns a standalone SVG into a one-page vector PDF of the same size.
@MainActor
enum PDFExporter {
    static func pdf(fromSVG svg: String, size: CGSize) async throws -> Data {
        let page = WebPage(navigationDecider: LocalContentNavigationDecider())
        for try await _ in page.load(html: html(embedding: svg)) {}
        return try await page.exported(as: .pdf(region: .rect(CGRect(origin: .zero, size: size))))
    }

    nonisolated static func html(embedding svg: String) -> String {
        let body = svg.replacingOccurrences(
            of: #"^<\?xml[^>]*\?>\s*"#, with: "", options: .regularExpression
        )
        return """
            <!doctype html><html><head><meta charset="utf-8">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">
            <style>html,body{margin:0;padding:0;background:transparent}svg{display:block}</style>
            </head><body>\(body)</body></html>
            """
    }
}
