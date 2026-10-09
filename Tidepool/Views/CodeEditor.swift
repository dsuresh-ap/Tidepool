import AppKit
import SwiftUI

/// A plain-text code editor for Mermaid source.
///
/// Unlike `TextEditor`, it turns off smart quotes and smart dashes, which would change
/// arrows such as `-->`. It colors the source, marks the line that has an error, and
/// suggests words when you pause while typing (press Esc to show suggestions at any time).
struct CodeEditor: NSViewRepresentable {
    /// A request to select a line and scroll to it. A new `id` repeats the request.
    struct LineRequest: Equatable {
        var line: Int
        var id = UUID()
    }

    @Binding var text: String
    var errorLine: Int?
    var reveal: LineRequest?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        textView.string = text
        textView.font = Coordinator.font
        textView.typingAttributes = [.font: Coordinator.font, .foregroundColor: NSColor.textColor]
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.setAccessibilityIdentifier("editor")
        textView.setAccessibilityLabel("Mermaid source")
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let length = (text as NSString).length
            let selection = textView.selectedRanges.filter { $0.rangeValue.upperBound <= length }
            textView.string = text
            textView.selectedRanges = selection.isEmpty ? [NSValue(range: NSRange(location: length, length: 0))] : selection
        }
        if coordinator.errorLine != errorLine, let storage = textView.textStorage {
            coordinator.errorLine = errorLine
            coordinator.style(storage)
        }
        if let reveal, reveal != coordinator.lastReveal {
            coordinator.lastReveal = reveal
            if let range = Coordinator.range(ofLine: reveal.line, in: textView.string) {
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(range)
                textView.scrollRangeToVisible(range)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: CodeEditor
        var errorLine: Int?
        var lastReveal: LineRequest?
        private var lastTypedText: String?

        init(parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            suggestIfTyping(in: textView)
        }

        // MARK: Completion

        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            lastTypedText = replacementString
            return true
        }

        func textView(
            _ textView: NSTextView,
            completions words: [String],
            forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>?
        ) -> [String] {
            let source = textView.string
            let prefix = (source as NSString).substring(with: charRange)
            let suggestions = MermaidCompletion.suggestions(
                for: prefix, in: source, atFirstStatement: Self.isAtFirstStatement(charRange, in: source)
            )
            index?.pointee = suggestions.isEmpty ? -1 : 0
            return suggestions
        }

        private var pendingSuggestion: DispatchWorkItem?

        /// Shows suggestions when typing pauses after two or more letters of a word.
        /// Waiting for a pause keeps the list from interrupting fast typing.
        private func suggestIfTyping(in textView: NSTextView) {
            pendingSuggestion?.cancel()
            defer { lastTypedText = nil }
            guard let typed = lastTypedText, typed.count == 1, typed.first?.isLetter == true else { return }
            let cursor = textView.selectedRange()
            let work = DispatchWorkItem { [weak textView] in
                guard let textView, textView.selectedRange() == cursor, cursor.length == 0 else { return }
                let partial = textView.rangeForUserCompletion
                guard partial.location != NSNotFound, NSMaxRange(partial) == cursor.location, partial.length >= 2 else { return }
                let suggestions = MermaidCompletion.suggestions(
                    for: (textView.string as NSString).substring(with: partial), in: textView.string,
                    atFirstStatement: Self.isAtFirstStatement(partial, in: textView.string)
                )
                if !suggestions.isEmpty { textView.complete(nil) }
            }
            pendingSuggestion = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }

        private static func isAtFirstStatement(_ range: NSRange, in source: String) -> Bool {
            guard let first = MermaidSyntax.firstStatement(in: source) else { return true }
            let firstLine = NSRange(first, in: source)
            return range.location >= firstLine.location && range.location <= NSMaxRange(firstLine)
        }

        // MARK: Styling

        /// Colors the source after each edit. Diagram files are small, so the whole text is styled.
        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            applyStyles(to: textStorage)
        }

        /// Restyles outside of an edit, for example when the error line changes.
        func style(_ textStorage: NSTextStorage) {
            textStorage.beginEditing()
            applyStyles(to: textStorage)
            textStorage.endEditing()
        }

        private func applyStyles(to textStorage: NSTextStorage) {
            let all = NSRange(location: 0, length: textStorage.length)
            for key: NSAttributedString.Key in [.foregroundColor, .font, .backgroundColor, .underlineStyle, .underlineColor] {
                textStorage.removeAttribute(key, range: all)
            }
            textStorage.addAttributes([.foregroundColor: NSColor.textColor, .font: Self.font], range: all)
            for (range, token) in MermaidSyntax.tokens(in: textStorage.string) {
                textStorage.addAttributes(Self.attributes(for: token), range: range)
            }
            if let errorLine, let range = Self.range(ofLine: errorLine, in: textStorage.string), range.length > 0 {
                textStorage.addAttributes([
                    .backgroundColor: NSColor.systemRed.withAlphaComponent(0.14),
                    .underlineStyle: NSUnderlineStyle.thick.rawValue | NSUnderlineStyle.patternDot.rawValue,
                    .underlineColor: NSColor.systemRed,
                ], range: range)
            }
        }

        /// The range of a 1-based line, without its line break.
        static func range(ofLine line: Int, in source: String) -> NSRange? {
            let text = source as NSString
            var location = 0
            var current = 1
            while current < line {
                let next = text.range(of: "\n", range: NSRange(location: location, length: text.length - location))
                guard next.location != NSNotFound else { return nil }
                location = NSMaxRange(next)
                current += 1
            }
            var contentsEnd = 0
            text.getLineStart(nil, end: nil, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            return NSRange(location: location, length: contentsEnd - location)
        }

        static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        private static let tide = NSColor(named: "AccentColor") ?? .systemTeal

        private static func attributes(for token: MermaidSyntax.Token) -> [NSAttributedString.Key: Any] {
            switch token {
            case .keyword: [.foregroundColor: tide, .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)]
            case .arrow: [.foregroundColor: tide]
            case .string: [.foregroundColor: NSColor.systemBrown]
            case .comment: [.foregroundColor: NSColor.secondaryLabelColor]
            }
        }
    }
}
