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

    /// **SF Pro ROUNDED, like every other word in the app.**
    ///
    /// This was `.preferredFont(forTextStyle: .body)`, which is SF Pro. So the
    /// one screen in Strata that is mostly typing was the one screen set in a
    /// face the rest of the app does not use: `Typography` is `design: .default`
    /// throughout and CLAUDE.md settles it as "SF Pro Rounded, two weights".
    /// Nothing errors, nothing looks broken, the letterforms are simply not the
    /// app's.
    ///
    /// Built from the DEFAULT body size and then scaled by `UIFontMetrics`,
    /// because that is the form `adjustsFontForContentSizeCategory` can grow;
    /// scaling a font that has already been scaled applies Dynamic Type twice.
    /// Falls back to the plain preferred font if the rounded design is refused,
    /// which is the same shape of guard `DynamicScreenTitle` uses for coverage.
    private static var lineFont: UIFont {
        let base = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
        guard let rounded = base.fontDescriptor.withDesign(.default) else {
            return UIFont.preferredFont(forTextStyle: .body)
        }
        return UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: UIFont(descriptor: rounded, size: base.pointSize))
    }

    func makeUIView(context: Context) -> Field {
        let field = Field()
        field.delegate = context.coordinator
        field.font = Self.lineFont
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
        //
        // **The app's inks, not `UIColor.label`.** Section 4 allows only
        // `AppColors` or a colour taken from content, and CLAUDE.md's rule is
        // sharper: `label` at 0.35 is a fixed fraction of a colour that inverts,
        // so the quiet state was 35% black on the light page and 35% white on
        // the dark one, which is the fault that measured 1.08:1 under the
        // bullets beside it. `inkQuiet` is the token held to 3:1 in both, which
        // is the right bar for something deliberately not being read.
        // `UIColor(_:)` keeps a dynamic `Color` dynamic, so both still follow
        // the scheme.
        field.textColor = UIColor(isDone ? AppColors.inkQuiet : AppColors.inkPrimary)
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
