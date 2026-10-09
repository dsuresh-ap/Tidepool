import Foundation

/// Finds the parts of Mermaid source that the editor colors.
enum MermaidSyntax {
    enum Token: Equatable {
        /// The diagram keyword on the first statement, such as `flowchart`.
        case keyword
        /// Links and messages, such as `-->`, `->>`, and `-.->`.
        case arrow
        /// Quoted text.
        case string
        /// `%%` comments, `%%{ }%%` directives, and YAML front matter.
        case comment
    }

    private static let frontMatter = /\A---\R[\s\S]*?\R---(?=\R|\z)/
    private static let comment = /%%.*/
    private static let string = /"[^"\n]*"/
    // Links and messages: -->, ---, ==>, -.->, --x, <-->, ~~~, and ->, ->>, -), -x followed by a space.
    private static let arrow = /<?[-=.~]{2,}(?:>>|>|x|o|\))?|-(?:>>|>|\)|x(?=\s))/
    private static let keyword = /^\s*([A-Za-z][\w-]*)/

    /// Returns tokens as UTF-16 ranges, so they map directly onto `NSString` and `NSTextView`.
    static func tokens(in source: String) -> [(range: NSRange, token: Token)] {
        var result: [(NSRange, Token)] = []
        var covered = IndexSet()

        func add(_ range: Range<String.Index>, _ token: Token) {
            let nsRange = NSRange(range, in: source)
            let indexes = IndexSet(integersIn: nsRange.location..<(nsRange.location + nsRange.length))
            guard nsRange.length > 0, covered.intersection(indexes).isEmpty else { return }
            covered.formUnion(indexes)
            result.append((nsRange, token))
        }

        // Comments win over strings and arrows inside them; strings win over arrows.
        if let match = source.firstMatch(of: frontMatter) { add(match.range, .comment) }
        for match in source.matches(of: comment) { add(match.range, .comment) }
        for match in source.matches(of: string) { add(match.range, .string) }
        if let line = firstStatement(in: source), let match = source[line].firstMatch(of: keyword),
           DiagramKind.detect(in: String(source[line])) != nil {
            add(match.1.startIndex..<match.1.endIndex, .keyword)
        }
        for match in source.matches(of: arrow) { add(match.range, .arrow) }
        return result.sorted { $0.0.location < $1.0.location }
    }

    /// The range of the first line that is not blank, a comment, or YAML front matter.
    private static func firstStatement(in source: String) -> Range<String.Index>? {
        var inFrontMatter = false
        var isFirst = true
        var start = source.startIndex
        while start < source.endIndex {
            let end = source[start...].firstIndex(where: \.isNewline) ?? source.endIndex
            let line = source[start..<end].trimmingCharacters(in: .whitespaces)
            if line == "---", isFirst || inFrontMatter {
                inFrontMatter.toggle()
            } else if !inFrontMatter, !line.isEmpty, !line.hasPrefix("%%") {
                return start..<end
            }
            isFirst = false
            start = end < source.endIndex ? source.index(after: end) : end
        }
        return nil
    }
}
