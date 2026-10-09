import XCTest

final class EditorUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES", "-NSQuitAlwaysKeepsWindows", "NO"]
        app.launch()
        openNewDocument()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testNewDocumentShowsRenderedFlowchart() {
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue(diagramKind.waitForExistence(timeout: 20))
        XCTAssertEqual(diagramKind.value as? String, "Flowchart")
        XCTAssertTrue(exportMenu.wait(for: \.isEnabled, toEqual: true, timeout: 20), "Export stays disabled until a diagram renders")
    }

    func testSyntaxErrorShowsMessageAndCanBeFixed() {
        XCTAssertTrue(diagramKind.waitForExistence(timeout: 20))
        replaceSource(with: "flowchart LR\n    A --> ")
        XCTAssertTrue(app.descendants(matching: .any)["renderError"].waitForExistence(timeout: 10))

        replaceSource(with: "flowchart LR\n    A --> B")
        XCTAssertTrue(diagramKind.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["renderError"].exists)
    }

    func testExamplesMenuReplacesUnchangedDocument() {
        XCTAssertTrue(diagramKind.waitForExistence(timeout: 20))
        app.toolbars.menuButtons["Examples"].click()
        app.menuItems["Sequence Diagram"].firstMatch.click()
        let kindChanged = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Sequence Diagram"), object: diagramKind)
        XCTAssertEqual(XCTWaiter().wait(for: [kindChanged], timeout: 10), .completed)
        XCTAssertTrue((editor.value as? String ?? "").hasPrefix("sequenceDiagram"))
    }

    func testExportMenuOffersSVGPNGAndPDF() {
        XCTAssertTrue(diagramKind.waitForExistence(timeout: 20))
        XCTAssertTrue(exportMenu.wait(for: \.isEnabled, toEqual: true, timeout: 20))
        exportMenu.click()
        for title in ["SVG Image…", "PNG Image…", "PDF Document…"] {
            XCTAssertTrue(app.menuItems[title].firstMatch.waitForExistence(timeout: 5), "Missing \(title)")
        }
        app.menuItems["PNG Image…"].firstMatch.click()

        let savePanel = app.sheets.firstMatch
        XCTAssertTrue(savePanel.waitForExistence(timeout: 10), "The save panel did not open")
        savePanel.buttons["Cancel"].click()
    }

    // MARK: - Helpers

    private var editor: XCUIElement { app.textViews["editor"].firstMatch }
    private var diagramKind: XCUIElement { app.descendants(matching: .any)["diagramKind"].firstMatch }
    private var exportMenu: XCUIElement { app.toolbars.menuButtons["Export"].firstMatch }

    private func openNewDocument() {
        // An open panel can appear at launch. Close it and make a new document.
        let openPanel = app.windows["open-panel"]
        if openPanel.waitForExistence(timeout: 5) {
            app.typeKey(.escape, modifierFlags: [])
            XCTAssertTrue(openPanel.waitForNonExistence(timeout: 5))
        }
        if !editor.waitForExistence(timeout: 2) {
            app.typeKey("n", modifierFlags: .command)
        }
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "No document window opened")
    }

    private func replaceSource(with text: String) {
        editor.click()
        app.typeKey("a", modifierFlags: .command)
        editor.typeText(text)
    }
}


final class ViewerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        let openPanel = app.windows["open-panel"]
        if openPanel.waitForExistence(timeout: 5) { app.typeKey(.escape, modifierFlags: []) }
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private var editor: XCUIElement { app.textViews["editor"].firstMatch }
    private var exportMenu: XCUIElement { app.toolbars.menuButtons["Export"].firstMatch }

    func testNewFromClipboardExtractsMermaidBlock() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Sure:\n```mermaid\nstateDiagram-v2\n    [*] --> Ready\n```\n", forType: .string)
        app.typeKey("n", modifierFlags: [.command, .shift])

        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertEqual(editor.value as? String, "stateDiagram-v2\n    [*] --> Ready")
        let kind = app.staticTexts["diagramKind"].firstMatch
        XCTAssertTrue(kind.waitForExistence(timeout: 20))
        XCTAssertEqual(kind.value as? String, "State Diagram")
    }

    func testSourceToggleHidesAndShowsEditor() {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        app.typeKey("s", modifierFlags: [.control, .command])
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["diagramKind"].firstMatch.exists, "The preview stays visible")

        app.toolbars.buttons["sourceToggle"].click()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
    }

    func testZoomShortcutsChangeZoomLabel() {
        app.typeKey("n", modifierFlags: .command)
        let fit = app.toolbars.buttons["Zoom to Fit"].firstMatch
        XCTAssertTrue(fit.waitForExistence(timeout: 10))
        XCTAssertEqual(fit.value as? String, "Fit")

        app.typeKey("=", modifierFlags: .command)
        let zoomedIn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "125%"), object: fit)
        XCTAssertEqual(XCTWaiter().wait(for: [zoomedIn], timeout: 5), .completed)
        app.typeKey("0", modifierFlags: .command)
        XCTAssertEqual(fit.value as? String, "Fit")
    }

    func testCopyAsMarkdownPutsCodeBlockOnPasteboard() {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(exportMenu.wait(for: \.isEnabled, toEqual: true, timeout: 20))
        exportMenu.click()
        app.menuItems["Copy as Markdown"].firstMatch.click()

        XCTAssertTrue(app.descendants(matching: .any)["confirmation"].waitForExistence(timeout: 5))
        let copied = NSPasteboard.general.string(forType: .string) ?? ""
        XCTAssertTrue(copied.hasPrefix("```mermaid\nflowchart TD\n"), copied)
        XCTAssertTrue(copied.hasSuffix("```\n"))
    }

    func testEmptyDocumentShowsGuidance() {
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["No Diagram"].waitForExistence(timeout: 5))
        XCTAssertFalse(exportMenu.isEnabled)
    }
}
