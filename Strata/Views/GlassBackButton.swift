import SwiftUI
import UIKit

/// **One glass style per bar** (the cohesion pass, 2026-10-05).
///
/// A pushed page with a glass button of ours in its trailing corner (the
/// journal on a past day, Play and the journal on a crew's day) had the
/// SYSTEM back button in its leading one: iOS 26 draws that in its own
/// toolbar capsule, `.regular` glass, while ours is `GlassRecipe.onPage`,
/// with the lift taken off. Two materials on one bar, one of them the "sore
/// thumb" the owner rejected on 2026-09-30, side by side. So the back button
/// is ours too: the same `GlassIconButton`, a chevron, `onPage`, with the
/// toolbar's shared capsule hidden, which is how `MapBackButton` and every
/// header in the app already make their corners.
///
/// **The edge swipe stays.** Hiding the system back button switches off
/// UIKit's interactive pop with it; `SwipeBackKeeper` turns it back on for
/// the life of the page, because a way back that only works as a button is
/// worse than the one it replaced.
struct GlassBackButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar { GlassBackToolbarItem { dismiss() } }
            .background { SwipeBackKeeper().frame(width: 0, height: 0) }
    }
}

extension View {
    /// The page's back button as the app's own glass. See `GlassBackButton`.
    func glassBackButton() -> some View { modifier(GlassBackButton()) }
}

private struct GlassBackToolbarItem: ToolbarContent {
    let action: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { button }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { button }
        }
    }

    private var button: some View {
        GlassIconButton(systemName: "chevron.left", onPage: true, accessibilityLabel: "Back", action: action)
    }
}

/// Keeps the navigation controller's edge swipe working on a page whose back
/// button is hidden, and gives the controller its own behaviour back when
/// the page goes.
private struct SwipeBackKeeper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Keeper { Keeper() }
    func updateUIViewController(_ controller: Keeper, context: Context) {}

    final class Keeper: UIViewController, UIGestureRecognizerDelegate {
        private weak var owner: UINavigationController?
        private weak var previous: UIGestureRecognizerDelegate?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController, let pop = nav.interactivePopGestureRecognizer,
                  pop.delegate !== self else { return }
            owner = nav
            previous = pop.delegate
            pop.delegate = self
            pop.isEnabled = true
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let pop = owner?.interactivePopGestureRecognizer, pop.delegate === self {
                pop.delegate = previous
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let nav = owner else { return false }
            return nav.viewControllers.count > 1 && nav.transitionCoordinator == nil
        }
    }
}
