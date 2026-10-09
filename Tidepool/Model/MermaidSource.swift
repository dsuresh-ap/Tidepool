import Foundation

/// Helpers for Mermaid source that comes from other apps.
nonisolated enum MermaidSource {
    private static let fence = /(?m)^[ \t]*(`{3,}|~{3,})[ \t]*mermaid[^\n]*\n([\s\S]*?)\n[ \t]*\1[ \t]*$/

    /// Returns the Mermaid code in `text`. When `text` is Markdown (for example a chat reply or a
    /// README), returns the content of the first ```` ```mermaid ```` block. Otherwise returns `text`.
    static func extract(from text: String) -> String {
        guard let match = text.firstMatch(of: fence) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(match.2)
    }

    /// Wraps source in a Markdown code block that GitHub, GitLab, and Notion render as a diagram.
    static func markdown(for source: String) -> String {
        "```mermaid\n\(source.trimmingCharacters(in: .newlines))\n```\n"
    }
}
