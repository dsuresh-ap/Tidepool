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

