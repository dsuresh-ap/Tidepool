import Foundation

/// Maps the line in a Mermaid error to the line in the editor.
nonisolated enum MermaidErrorLocation {
    private static let messageLine = /line (\d+), column/
    private static let jisonLine = /(?i)(parse error on line )\d+/

    /// Returns the 1-based editor line for an error, or `nil` if Mermaid did not report a line.
    ///
    /// Mermaid counts lines after it removes YAML front matter, `%%` comment and directive lines,
    /// and blank lines before the diagram. This function skips the same lines to undo that.
    /// - Parameters:
    ///   - reported: The line from the parser's error location (older diagram types).
    ///   - message: The error message. Newer diagram types put "line N, column M" in it.
    static func sourceLine(reported: Int?, message: String, in source: String) -> Int? {
        guard let line = reported ?? message.firstMatch(of: messageLine).flatMap({ Int($0.1) }), line > 0 else {
            return nil
        }
        var kept = 0
        var lastKept: Int?
        var lastContent: Int?
        var inFrontMatter = false
        for (index, rawLine) in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            let text = rawLine.trimmingCharacters(in: .whitespaces)
            if index == 0, text == "---" { inFrontMatter = true; continue }
            if inFrontMatter { if text == "---" { inFrontMatter = false }; continue }
            if text.hasPrefix("%%") || (lastKept == nil && text.isEmpty) { continue }
            kept += 1
            lastKept = index + 1
            if !text.isEmpty { lastContent = index + 1 }
            if kept == line { return text.isEmpty ? lastContent : index + 1 }
        }
        // The parser can report the end of the text. Point at the last line with content.
        return lastContent
    }

    /// Rewrites the line numbers in Mermaid's message so they match the editor.
    static func displayMessage(_ message: String, line: Int?) -> String {
        guard let line else { return message }
        return message
            .replacing(jisonLine) { "\($0.1)\(line)" }
            .replacing(messageLine) { _ in "line \(line), column" }
    }
}
