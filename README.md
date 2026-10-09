# Tidepool

A lightweight, native Mermaid diagram viewer and editor for macOS.

Write [Mermaid](https://mermaid.js.org) on the left and see the diagram on the right as you type. Open the `.mmd` files that your tools generate, keep many of them open as tabs, and export them as SVG, PNG, or PDF.

## Features

- **Live preview.** The preview updates as you type. When the source has an error, the last good diagram stays on screen and the Mermaid error shows below it.
- **Many diagrams at once.** Each document opens as a tab. Drag a tab out to make a window, or tile two windows side by side.
- **Export.** SVG for the web and design tools, PNG (2×) for chat and slides, PDF for print. Exported SVG files use plain SVG text, so Figma, Inkscape, and Keynote show the labels correctly.
- **All Mermaid diagram types.** Flowchart, sequence, class, state, ER, Gantt, pie, mind map, timeline, Git graph, and more. The Examples menu gives you a starting point for each.
- **Themes.** Automatic (follows Light or Dark Mode), Default, Neutral, Forest, and Dark.
- **Works offline.** Mermaid is bundled in the app. The preview cannot load remote content.

## Requirements

- macOS 27 or later
- Xcode 27 or later (to build)

iOS, iPadOS, and visionOS support is planned.

## Build and run

```bash
git clone https://github.com/dsuresh-ap/Tidepool.git
cd Tidepool
open Tidepool.xcodeproj
```

Select the **Tidepool** scheme and press **⌘R**.

Run the unit and UI tests from Xcode (**⌘U**) or from the command line:

```bash
xcodebuild test -project Tidepool.xcodeproj -scheme Tidepool -destination 'platform=macOS'
```

## How it works

Tidepool is a SwiftUI document app with no Swift package dependencies.

| Part | File |
| --- | --- |
| Document model (`.mmd`, `.mermaid`, plain text) | `Tidepool/Model/MermaidDocument.swift` |
| Diagram type detection and examples | `Tidepool/Model/DiagramKind.swift` |
| Preview and export (SwiftUI `WebView` and bundled `mermaid.min.js`) | `Tidepool/Rendering/` |
| Editor window | `Tidepool/Views/` |

The preview page runs Mermaid with `securityLevel: 'strict'` and a Content Security Policy that allows only the app's own scripts. A diagram cannot run scripts, load remote content, or navigate the preview. The app turns on the sandbox's outgoing-connections entitlement only because WebKit's content process needs it in a sandboxed app.

## Third-party code

Tidepool bundles [Mermaid](https://github.com/mermaid-js/mermaid) 12.1.0 (`Tidepool/Resources/mermaid.min.js`), © Knut Sveidqvist and contributors, under the MIT License. See `Tidepool/Resources/mermaid-LICENSE.txt`.

To update Mermaid, replace `mermaid.min.js` with the `dist/mermaid.min.js` file from the npm package and run the tests.

## License

[MIT](LICENSE)
