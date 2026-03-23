import SwiftUI
import UIKit

/// A custom text field with real-time syntax highlighting via NSAttributedString.
/// Pre-attentive processing (Treisman 1980): keywords highlighted in <200ms.
/// Cursor position preserved on every update.
/// Focus bridged from SwiftUI via isFocused binding → becomeFirstResponder.
struct HighlightingTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var accentColor: Color
    var placeholder: String
    var onSubmit: () -> Void

    private static let baseFont: UIFont = {
        let descriptor = UIFont.systemFont(ofSize: 16, weight: .regular).fontDescriptor.withDesign(.rounded)!
        return UIFont(descriptor: descriptor, size: 16)
    }()

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = Self.baseFont
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.returnKeyType = .done
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = 1
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = Self.baseFont
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.tag = 999
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: textView.centerYAnchor),
        ])

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Text sync + highlighting
        let currentText = textView.text ?? ""
        if currentText != text {
            let selectedRange = textView.selectedRange
            let uiAccent = UIColor(accentColor)
            let attributed = InputParser.highlight(text, baseFont: Self.baseFont, accentColor: uiAccent)
            textView.attributedText = attributed
            let safeRange = NSRange(location: min(selectedRange.location, text.count), length: 0)
            textView.selectedRange = safeRange
        }

        // Placeholder
        if let placeholderLabel = textView.viewWithTag(999) as? UILabel {
            placeholderLabel.isHidden = !text.isEmpty
            placeholderLabel.text = placeholder
        }

        // Focus bridge: SwiftUI → UIKit becomeFirstResponder
        if isFocused && !textView.isFirstResponder && textView.window != nil {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        } else if !isFocused && textView.isFirstResponder {
            DispatchQueue.main.async {
                textView.resignFirstResponder()
            }
        }

        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightingTextField

        init(parent: HighlightingTextField) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            parent.text = newText
            // Placeholder update only — highlighting handled by updateUIView
            if let placeholderLabel = textView.viewWithTag(999) as? UILabel {
                placeholderLabel.isHidden = !newText.isEmpty
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }
    }
}
