import Foundation

/// The Mermaid diagram types that Tidepool recognizes, with a starter example for each.
enum DiagramKind: String, CaseIterable, Identifiable {
    case flowchart, sequence, classDiagram, state, entityRelationship, gantt, pie,
         mindmap, timeline, gitGraph, userJourney, quadrant, xyChart, sankey,
         requirement, c4, block, packet, kanban, architecture, radar, treemap

    var id: Self { self }

    /// Kinds offered in the Examples menu, in display order.
    static let examples: [DiagramKind] = [
        .flowchart, .sequence, .classDiagram, .state, .entityRelationship,
        .gantt, .pie, .mindmap, .timeline, .gitGraph, .userJourney, .quadrant, .xyChart,
    ]

    var title: String {
        switch self {
        case .flowchart: "Flowchart"
        case .sequence: "Sequence Diagram"
        case .classDiagram: "Class Diagram"
        case .state: "State Diagram"
        case .entityRelationship: "Entity Relationship Diagram"
        case .gantt: "Gantt Chart"
        case .pie: "Pie Chart"
        case .mindmap: "Mind Map"
        case .timeline: "Timeline"
        case .gitGraph: "Git Graph"
        case .userJourney: "User Journey"
        case .quadrant: "Quadrant Chart"
        case .xyChart: "XY Chart"
        case .sankey: "Sankey Diagram"
        case .requirement: "Requirement Diagram"
        case .c4: "C4 Diagram"
        case .block: "Block Diagram"
        case .packet: "Packet Diagram"
        case .kanban: "Kanban Board"
        case .architecture: "Architecture Diagram"
        case .radar: "Radar Chart"
        case .treemap: "Treemap"
        }
    }

    var systemImage: String {
        switch self {
        case .flowchart: "arrow.triangle.branch"
        case .sequence: "arrow.left.arrow.right"
        case .classDiagram: "square.stack.3d.up"
        case .state: "circle.circle"
        case .entityRelationship: "tablecells"
        case .gantt: "calendar"
        case .pie: "chart.pie"
        case .mindmap: "brain"
        case .timeline: "clock"
        case .gitGraph: "point.topleft.down.to.point.bottomright.curvepath"
        case .userJourney: "figure.walk"
        case .quadrant: "square.grid.2x2"
        case .xyChart: "chart.xyaxis.line"
        default: "chart.dots.scatter"
        }
    }

    /// Every keyword that starts a diagram, for completion.
    static var allKeywords: [String] { allCases.flatMap(\.keywords) }

    /// Mermaid keywords that start a diagram of this kind.
    private var keywords: [String] {
        switch self {
        case .flowchart: ["flowchart", "graph", "flowchart-elk"]
        case .sequence: ["sequenceDiagram"]
        case .classDiagram: ["classDiagram", "classDiagram-v2"]
        case .state: ["stateDiagram", "stateDiagram-v2"]
        case .entityRelationship: ["erDiagram"]
        case .gantt: ["gantt"]
        case .pie: ["pie"]
        case .mindmap: ["mindmap"]
        case .timeline: ["timeline"]
        case .gitGraph: ["gitGraph"]
        case .userJourney: ["journey"]
        case .quadrant: ["quadrantChart"]
        case .xyChart: ["xychart", "xychart-beta"]
        case .sankey: ["sankey", "sankey-beta"]
        case .requirement: ["requirementDiagram"]
        case .c4: ["C4Context", "C4Container", "C4Component", "C4Dynamic", "C4Deployment"]
        case .block: ["block", "block-beta"]
        case .packet: ["packet", "packet-beta"]
        case .kanban: ["kanban"]
        case .architecture: ["architecture", "architecture-beta"]
        case .radar: ["radar", "radar-beta"]
        case .treemap: ["treemap", "treemap-beta"]
        }
    }

    /// Finds the diagram kind from the first statement of Mermaid source.
    /// Skips YAML front matter, `%%` comments, `%%{init}%%` directives, and blank lines.
    static func detect(in source: String) -> DiagramKind? {
        var inFrontMatter = false
        var isFirstLine = true
        for rawLine in source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            defer { isFirstLine = false }
            if line == "---" {
                if isFirstLine || inFrontMatter { inFrontMatter.toggle(); continue }
            }
            if inFrontMatter || line.isEmpty || line.hasPrefix("%%") { continue }

            let keyword = line.prefix { !$0.isWhitespace && $0 != ";" && $0 != ":" }
            return allCases.first { $0.keywords.contains(String(keyword)) }
        }
        return nil
    }

    var example: String {
        switch self {
        case .flowchart: """
            flowchart TD
                A[Start] --> B{Is it working?}
                B -- Yes --> C[Ship it]
                B -- No --> D[Debug]
                D --> B
            """
        case .sequence: """
            sequenceDiagram
                participant App
                participant API
                App->>API: GET /diagrams
                API-->>App: 200 OK
                App->>App: Render preview
            """
        case .classDiagram: """
            classDiagram
                class Diagram {
                    +String source
                    +render() SVG
                }
                class Export {
                    +String format
                }
                Diagram "1" --> "*" Export
            """
        case .state: """
            stateDiagram-v2
                [*] --> Draft
                Draft --> Review: submit
                Review --> Draft: request changes
                Review --> Published: approve
                Published --> [*]
            """
        case .entityRelationship: """
            erDiagram
                CUSTOMER ||--o{ ORDER : places
                ORDER ||--|{ LINE_ITEM : contains
                PRODUCT ||--o{ LINE_ITEM : "appears in"
            """
        case .gantt: """
            gantt
                title Release plan
                dateFormat YYYY-MM-DD
                section Build
                    Editor     :a1, 2026-01-05, 10d
                    Preview    :a2, after a1, 7d
                section Ship
                    Beta       :after a2, 5d
            """
        case .pie: """
            pie title Diagram types used
                "Flowchart" : 45
                "Sequence" : 30
                "Class" : 15
                "Other" : 10
            """
        case .mindmap: """
            mindmap
              root((Tidepool))
                Edit
                  Live preview
                  Examples
                Export
                  SVG
                  PNG
                  PDF
            """
        case .timeline: """
            timeline
                title Project history
                2024 : Idea
                2025 : Prototype
                2026 : Public release
            """
        case .gitGraph: """
            gitGraph
                commit
                branch feature
                checkout feature
                commit
                commit
                checkout main
                merge feature
                commit
            """
        case .userJourney: """
            journey
                title Make a diagram
                section Write
                    Open Tidepool: 5: Me
                    Type Mermaid: 4: Me
                section Share
                    Export PNG: 5: Me
            """
        case .quadrant: """
            quadrantChart
                title Effort vs impact
                x-axis Low effort --> High effort
                y-axis Low impact --> High impact
                quadrant-1 Plan
                quadrant-2 Do now
                quadrant-3 Skip
                quadrant-4 Delegate
                Export: [0.3, 0.8]
                Themes: [0.2, 0.4]
                Plugins: [0.8, 0.6]
            """
        case .xyChart: """
            xychart-beta
                title "Exports per month"
                x-axis [Jan, Feb, Mar, Apr]
                y-axis "Exports" 0 --> 100
                bar [20, 45, 60, 90]
                line [20, 45, 60, 90]
            """
        default: "\(keywords[0])\n"
        }
    }
}
