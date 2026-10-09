import AppKit
import SwiftUI

/// A plain-text code editor. Unlike `TextEditor`, it turns off smart quotes and
/// smart dashes, which would change Mermaid arrows such as `-->`.
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String

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
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        let length = (text as NSString).length
        let selection = textView.selectedRanges.filter { $0.rangeValue.upperBound <= length }
        textView.string = text
        textView.selectedRanges = selection.isEmpty ? [NSValue(range: NSRange(location: length, length: 0))] : selection
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: CodeEditor

        init(parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        /// Colors the source after each edit. Diagram files are small, so the whole text is styled.
        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard editedMask.contains(.editedCharacters) else { return }
            let all = NSRange(location: 0, length: textStorage.length)
            textStorage.removeAttribute(.foregroundColor, range: all)
            textStorage.removeAttribute(.font, range: all)
            textStorage.addAttributes([.foregroundColor: NSColor.textColor, .font: Self.font], range: all)
            for (range, token) in MermaidSyntax.tokens(in: textStorage.string) {
                textStorage.addAttributes(Self.attributes(for: token), range: range)
            }
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
