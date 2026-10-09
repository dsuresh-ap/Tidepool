# Tidepool

A lightweight, native Mermaid diagram viewer and editor for macOS.

Write [Mermaid](https://mermaid.js.org) on the left and see the diagram on the right as you type. Open the `.mmd` files that your tools generate, keep many of them open as tabs, and export them as SVG, PNG, or PDF.

## Features

- **Live preview.** The preview updates as you type. When the source has an error, the last good diagram stays on screen, the broken line is marked in the source, and **Line N** in the error bar takes you to it.
- **Quick Look.** Select a `.mmd` file in Finder and press Space to see the diagram.
- **Code completion.** Suggestions appear when you pause while typing a word: diagram types on the first line, then keywords for that diagram type and the names you already use. Press Esc to show them at any time.
- **Follows generated files.** When a script or tool rewrites an open `.mmd` file, the window shows the new diagram. Unsaved edits in the window are kept.
- **Paste from anywhere.** **File › New Diagram from Clipboard** makes a diagram from copied Mermaid code. If you copy a chat reply or a README, Tidepool uses the first ```` ```mermaid ```` block.
- **Many diagrams at once.** Each document opens as a tab. Drag a tab out to make a window, or tile two windows side by side.
- **Viewer mode.** Hide the source to give the diagram the full window.
- **Export.** SVG for the web and design tools, PNG (2×) for chat and slides, PDF for print. Exported SVG files use plain SVG text, so Figma, Inkscape, and Keynote show the labels correctly.
- **Copy.** Copy the diagram as an image, or as a Markdown code block that GitHub, GitLab, and Notion render.
- **All Mermaid diagram types.** Flowchart, sequence, class, state, ER, Gantt, pie, mind map, timeline, Git graph, and more. The Examples menu gives you a starting point for each.
- **Themes.** Automatic (follows Light or Dark Mode), Default, Neutral, Forest, and Dark.
- **Works offline.** Mermaid is bundled in the app. The preview cannot load remote content.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| New diagram | ⌘N |
| New diagram from clipboard | ⇧⌘N |
| Show or hide source | ⌃⌘S |
| Zoom in / out | ⌘= / ⌘− |
| Fit to window | ⌘0 |
| Find in source | ⌘F |
| Show completions | Esc |

Pinch on the trackpad to zoom the preview.

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

Run the unit tests from Xcode (**⌘U**) or from the command line. They run in the background and do not take over the mouse or keyboard:

```bash
xcodebuild test -project Tidepool.xcodeproj -scheme Tidepool -destination 'platform=macOS'
```

The UI tests are in a separate scheme because they control the mouse and keyboard. Do not use the Mac while they run (about two minutes):

```bash
xcodebuild test -project Tidepool.xcodeproj -scheme "Tidepool UI Tests" -destination 'platform=macOS'
```

## How it works

Tidepool is a SwiftUI document app with no Swift package dependencies.

| Part | File |
| --- | --- |
| Document model (`.mmd`, `.mermaid`, plain text) | `Shared/Model/MermaidDocument.swift` |
| Diagram type detection and examples | `Shared/Model/DiagramKind.swift` |
| Source coloring, completion, and error lines | `Shared/Model/MermaidSyntax.swift`, `MermaidCompletion.swift`, `MermaidErrorLocation.swift` |
| Clipboard and Markdown helpers | `Shared/Model/MermaidSource.swift` |
| Reload when the file changes on disk | `Shared/Model/FileChanges.swift` |
| Preview and export (SwiftUI `WebView` and bundled `mermaid.min.js`) | `Shared/Rendering/` |
| Editor window | `Tidepool/Views/` |
| Finder Quick Look extension | `TidepoolQuickLook/` |

The app and the Quick Look extension both build the files in `Shared/`.

The preview page runs Mermaid with `securityLevel: 'strict'` and a Content Security Policy that allows only the app's own scripts. A diagram cannot run scripts, load remote content, or navigate the preview. The app turns on the sandbox's outgoing-connections entitlement only because WebKit's content process needs it in a sandboxed app.

## Third-party code

Tidepool bundles [Mermaid](https://github.com/mermaid-js/mermaid) 12.1.0 (`Shared/Resources/mermaid.min.js`), © Knut Sveidqvist and contributors, under the MIT License. See `Shared/Resources/mermaid-LICENSE.txt`.

The app icon is drawn by `scripts/make-icon.swift`.

To update Mermaid, replace `mermaid.min.js` with the `dist/mermaid.min.js` file from the npm package and run the tests.

## License

[MIT](LICENSE)
