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

    /// A swipe to the right anywhere on the page goes back (`SwipeBackKeeper`).
    func swipesBackFromAnywhere(unless busy: @escaping () -> Bool = { false }) -> some View {
        background { SwipeBackKeeper(fromAnywhere: true, allows: { !busy() }).frame(width: 0, height: 0) }
    }
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
///
/// **From anywhere** (`fromAnywhere`, the owner, 2026-10-15: "noticed that
/// you can scroll back really easily in chats [on Instagram] ... tried it on
/// our app and it wasnt a function"): iOS 26's content pop as well, so a
/// swipe to the right anywhere on the page goes back, as Instagram's
/// conversations and Messages do, not only from the screen's edge.
struct SwipeBackKeeper: UIViewControllerRepresentable {
    var fromAnywhere = false
    /// Whether a swipe from the middle may go back right now.
    var allows: () -> Bool = { true }

    func makeUIViewController(context: Context) -> Keeper { Keeper(fromAnywhere: fromAnywhere) }
    func updateUIViewController(_ controller: Keeper, context: Context) { controller.allows = allows }

    final class Keeper: UIViewController, UIGestureRecognizerDelegate {
        private let fromAnywhere: Bool
        var allows: () -> Bool = { true }
        private weak var owner: UINavigationController?
        private weak var previous: UIGestureRecognizerDelegate?
        private weak var previousContent: UIGestureRecognizerDelegate?

        init(fromAnywhere: Bool) {
            self.fromAnywhere = fromAnywhere
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let nav = navigationController, let pop = nav.interactivePopGestureRecognizer,
                  pop.delegate !== self else { return }
            owner = nav
            previous = pop.delegate
            pop.delegate = self
            pop.isEnabled = true
            if fromAnywhere, #available(iOS 26.0, *), let content = nav.interactiveContentPopGestureRecognizer {
                previousContent = content.delegate
                content.delegate = self
                content.isEnabled = true
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let pop = owner?.interactivePopGestureRecognizer, pop.delegate === self {
                pop.delegate = previous
            }
            if #available(iOS 26.0, *), let content = owner?.interactiveContentPopGestureRecognizer,
               content.delegate === self {
                content.delegate = previousContent
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let nav = owner, nav.viewControllers.count > 1, nav.transitionCoordinator == nil else { return false }
            // From the middle of the page, not while the page has a finger
            // busy (a reaction slid along its bar): the content pop judges
            // the direction itself, and its velocity is still nothing here.
            if #available(iOS 26.0, *), gestureRecognizer === nav.interactiveContentPopGestureRecognizer {
                return allows()
            }
            return true
        }
    }
}
