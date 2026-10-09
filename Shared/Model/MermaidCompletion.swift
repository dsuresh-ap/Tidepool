import Foundation

/// Suggests words while you type Mermaid source.
enum MermaidCompletion {
    /// Words that are useful inside each kind of diagram.
    static func keywords(for kind: DiagramKind?) -> [String] {
        switch kind {
        case .flowchart: ["subgraph", "end", "direction", "classDef", "class", "style", "linkStyle", "click", "TB", "TD", "BT", "LR", "RL"]
        case .sequence: ["participant", "actor", "activate", "deactivate", "Note", "left of", "right of", "over", "loop", "alt", "else", "opt", "par", "and", "critical", "break", "rect", "end", "autonumber", "box", "create", "destroy"]
        case .classDiagram: ["class", "namespace", "classDef", "cssClass", "direction", "note", "style"]
        case .state: ["state", "note", "end note", "direction", "classDef", "class"]
        case .entityRelationship: ["string", "int", "float", "boolean", "date", "PK", "FK", "UK"]
        case .gantt: ["title", "dateFormat", "axisFormat", "tickInterval", "excludes", "weekends", "todayMarker", "section", "done", "active", "crit", "milestone", "after"]
        case .pie: ["title", "showData"]
        case .timeline, .userJourney: ["title", "section"]
        case .gitGraph: ["commit", "branch", "checkout", "merge", "cherry-pick", "NORMAL", "REVERSE", "HIGHLIGHT"]
        case .quadrant: ["title", "x-axis", "y-axis", "quadrant-1", "quadrant-2", "quadrant-3", "quadrant-4"]
        case .xyChart: ["title", "x-axis", "y-axis", "bar", "line", "horizontal"]
        default: ["title"]
        }
    }

    /// Returns completions for `prefix`. At the first statement it offers diagram types;
    /// after that it offers keywords for the diagram type and names already used in the source.
    static func suggestions(for prefix: String, in source: String, atFirstStatement: Bool) -> [String] {
        guard !prefix.isEmpty else { return [] }
        let candidates: [String]
        if atFirstStatement {
            candidates = DiagramKind.allKeywords
        } else {
            let names = source.matches(of: /[A-Za-z_][\w]*/).map { String($0.output) }
            let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
            // The word being typed appears once in the source; leave it out unless it is used elsewhere.
            let used = counts.filter { $0.key != prefix || $0.value > 1 }.keys.sorted()
            candidates = keywords(for: DiagramKind.detect(in: source)) + used
        }
        var seen = Set<String>()
        return candidates.filter { word in
            word.count > prefix.count
                && word.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil
                && seen.insert(word).inserted
        }
    }
}
