import SwiftUI
import UIKit

/// A plan line's text field.
///
/// SwiftUI's `TextField` cannot do the two things that make a bullet list feel
/// like a bullet list: it has no hook for **backspace on an empty line**, and
/// its `onSubmit` cannot tell you where the caret was. Both are what let you
/// write a list without ever reaching for a button — return makes the next
/// line, backspace removes the one you did not want — so this drops to
/// `UITextField`, which does expose them.
///
/// `deleteBackward()` is the override that matters. UIKit calls it for every
/// backspace, including the one on an empty field where there is nothing to
/// delete, which is exactly the keystroke a list has to treat as "remove this
/// line and put me on the end of the one above".
struct PlanTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    /// Which line owns the keyboard. Set to this field's id to focus it.
    @Binding var focused: UUID?
    let id: UUID
    var isDone: Bool
    /// Return pressed: make the next line.
    var onReturn: () -> Void
    /// Backspace on an already-empty line: remove this one.
    var onBackspaceWhenEmpty: () -> Void

    final class Field: UITextField {
        var onBackspaceWhenEmpty: (() -> Void)?
        override func deleteBackward() {
            let wasEmpty = text?.isEmpty ?? true
            super.deleteBackward()
            if wasEmpty { onBackspaceWhenEmpty?() }
        }
    }

    func makeUIView(context: Context) -> Field {
        let field = Field()
        field.delegate = context.coordinator
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .next
        field.autocorrectionType = .default
        field.enablesReturnKeyAutomatically = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)),
                        for: .editingChanged)
        field.onBackspaceWhenEmpty = { context.coordinator.parent.onBackspaceWhenEmpty() }
        return field
    }

    func updateUIView(_ field: Field, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.placeholder = placeholder
        // A finished line is quieter, but never struck through: this is a list
        // of what you did, and crossing it out reads as cancelled.
        field.textColor = isDone ? UIColor.label.withAlphaComponent(0.35) : .label
        field.onBackspaceWhenEmpty = { context.coordinator.parent.onBackspaceWhenEmpty() }

        // Focus is driven from outside so the list can move the caret when a
        // line is added or removed. Guarded both ways, or the field fights the
        // user for the keyboard on every redraw.
        if focused == id, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if focused != id, field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PlanTextField
        init(_ parent: PlanTextField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onReturn()
            return false
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            if parent.focused != parent.id { parent.focused = parent.id }
        }
    }
}
