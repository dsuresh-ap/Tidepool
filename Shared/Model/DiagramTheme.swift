import SwiftUI

/// A Mermaid theme. `.automatic` follows the system appearance.
enum DiagramTheme: String, CaseIterable, Identifiable {
    case automatic, `default`, neutral, forest, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .default: "Default"
        case .neutral: "Neutral"
        case .forest: "Forest"
        case .dark: "Dark"
        }
    }

    /// The theme name that Mermaid's `initialize` expects.
    func mermaidName(for colorScheme: ColorScheme) -> String {
        switch self {
        case .automatic: colorScheme == .dark ? "dark" : "default"
        default: rawValue
        }
    }

    /// The CSS color that fills the background of exported images.
    func exportBackground(for colorScheme: ColorScheme) -> String {
        mermaidName(for: colorScheme) == "dark" ? "#1e1e1e" : "#ffffff"
    }
}
