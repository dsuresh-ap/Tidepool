import Foundation
import Observation
import WebKit

/// Renders Mermaid source into the preview page and exports the result.
///
/// The page loads the bundled `mermaid.min.js` once. It never loads remote content
/// and it blocks all navigation away from the preview.
@MainActor @Observable
final class DiagramRenderer {
    enum RenderError: LocalizedError {
        case missingResource(String)
        case nothingToExport
        case invalidResult

        var errorDescription: String? {
            switch self {
            case .missingResource(let name): "The app bundle does not contain \(name)."
            case .nothingToExport: "There is no diagram to export. Fix the errors first."
            case .invalidResult: "The preview returned an unexpected result."
            }
        }
    }

    let page: WebPage
    /// The SVG markup of the last diagram that rendered without errors.
    private(set) var svg: String?
    /// The Mermaid error message for the current source, if any.
    private(set) var errorMessage: String?

    private var loading: Task<Void, Error>?

    init() {
        page = WebPage(navigationDecider: LocalContentNavigationDecider())
    }

    /// Renders `source`. Keeps the last good diagram on screen when the source has errors.
    func render(_ source: String, theme: String) async {
        do {
            try await loadIfNeeded()
            if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try await page.callJavaScript("window.tidepool.clear()")
                svg = nil
                errorMessage = nil
                return
            }
            let result = try await page.callJavaScript(
                "return await window.tidepool.render(code, theme)",
                arguments: ["code": source, "theme": theme]
            ) as? [String: Any]
            if let markup = result?["svg"] as? String {
                svg = markup
                errorMessage = nil
            } else {
                errorMessage = result?["error"] as? String ?? RenderError.invalidResult.localizedDescription
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setZoom(_ zoom: Double) async {
        _ = try? await page.callJavaScript("window.tidepool.setZoom(zoom)", arguments: ["zoom": zoom])
    }

    /// Exports the current diagram. `background` is a CSS color.
    func export(_ format: ExportFormat, background: String) async throws -> Data {
        guard svg != nil else { throw RenderError.nothingToExport }
        switch format {
        case .svg:
            let result = try await exportedSVG(background: background)
            return Data(result.markup.utf8)
        case .png:
            let encoded = try await page.callJavaScript(
                "return await window.tidepool.exportPNG(background, scale)",
                arguments: ["background": background, "scale": 2]
            ) as? String
            guard let encoded, let data = Data(base64Encoded: encoded) else { throw RenderError.invalidResult }
            return data
        case .pdf:
            let result = try await exportedSVG(background: background)
            return try await PDFExporter.pdf(fromSVG: result.markup, size: result.size)
        }
    }

    private func exportedSVG(background: String) async throws -> (markup: String, size: CGSize) {
        let result = try await page.callJavaScript(
            "return window.tidepool.exportSVG(background)",
            arguments: ["background": background]
        ) as? [String: Any]
        guard let markup = result?["svg"] as? String,
              let width = (result?["width"] as? NSNumber)?.doubleValue,
              let height = (result?["height"] as? NSNumber)?.doubleValue
        else { throw RenderError.invalidResult }
        return (markup, CGSize(width: width, height: height))
    }

    private func loadIfNeeded() async throws {
        if loading == nil {
            loading = Task { [page] in
                let html = try Self.previewHTML()
                for try await _ in page.load(html: html) {}
            }
        }
        try await loading?.value
    }

    /// Builds the preview page with Mermaid inlined and a fresh script nonce.
    static func previewHTML(bundle: Bundle = .main) throws -> String {
        guard let templateURL = bundle.url(forResource: "preview", withExtension: "html") else {
            throw RenderError.missingResource("preview.html")
        }
        guard let mermaidURL = bundle.url(forResource: "mermaid.min", withExtension: "js") else {
            throw RenderError.missingResource("mermaid.min.js")
        }
        let template = try String(contentsOf: templateURL, encoding: .utf8)
        let mermaid = try String(contentsOf: mermaidURL, encoding: .utf8)
        return inlinePreview(template: template, script: mermaid, nonce: UUID().uuidString)
    }

    /// Puts `script` into the template. Escapes `</script` so the script cannot end its element early.
    nonisolated static func inlinePreview(template: String, script: String, nonce: String) -> String {
        let safeScript = script.replacingOccurrences(of: "</script", with: "<\\/script", options: .caseInsensitive)
        return template
            .replacingOccurrences(of: "{{NONCE}}", with: nonce)
            .replacingOccurrences(of: "{{MERMAID}}", with: safeScript)
    }
}

/// Allows only the initial in-memory page load. Diagrams cannot navigate a page away.
struct LocalContentNavigationDecider: WebPage.NavigationDeciding {
    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        action.request.url?.scheme == "about" ? .allow : .cancel
    }
}
