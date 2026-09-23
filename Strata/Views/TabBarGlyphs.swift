import SwiftUI
import UIKit

/// **Makes the tab bar's glyphs legible against what is actually behind them.**
///
/// The owner: "why is the Home, when selected, black when it should be white?
/// I feel like there are problems with the bottom tab bar that need to be
/// tweaked, because we don't need it to reset every page any more — the
/// bottom is always in dark mode."
///
/// He is right about the cause. The bar takes its item colours from the
/// WINDOW's appearance, and Home pins the window to `.light` so the page can
/// be a warm white — so the bar drew dark glyphs. But the bar does not float
/// over the page: it floats over the 20pt strip of `Grey.g950` at the bottom
/// of it. Dark glyphs on the darkest grey in the app.
///
/// **What this can and cannot do, measured.** Four ways to make the bar dark
/// were tried and are written up in `MainAppView`; the background is owned by
/// Liquid Glass and nothing public reaches it. The ITEM COLOURS are a
/// different story — a `UITabBarAppearance` set on the bar instance does
/// apply them, and that was the one half of the fourth attempt that worked.
/// So this changes the glyphs and leaves the glass alone, which is all that
/// was wrong.
///
/// **Why it takes a tint rather than assuming white.** Every screen whose
/// bottom is dark wants white; a screen whose bottom is light would want the
/// system's own colours back, and forcing white there would hide the bar
/// entirely. Passing nil restores the default, so the rule lives at the call
/// site next to the screen that knows what colour its own floor is.
struct TabBarGlyphs: UIViewRepresentable {
    /// Nil restores the system's colours.
    var tint: UIColor?

    func makeUIView(context: Context) -> Probe {
        let probe = Probe()
        probe.isUserInteractionEnabled = false
        probe.tint = tint
        return probe
    }

    func updateUIView(_ probe: Probe, context: Context) {
        probe.tint = tint
        probe.apply()
    }

    final class Probe: UIView {
        var tint: UIColor?
        /// What the bar looked like before this touched it, so nil can put it
        /// back rather than guessing at the system's values.
        private var original: UITabBarAppearance?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }

        func apply() {
            guard let bar = tabBarController()?.tabBar else { return }
            if original == nil { original = bar.standardAppearance }
            guard let tint else {
                if let original { bar.standardAppearance = original; bar.scrollEdgeAppearance = original }
                return
            }
            // **The background is deliberately untouched.** Setting it is
            // what produced the half-applied state last time: the item
            // colours changed and the glass did not, leaving white glyphs on
            // a light bar. Copying the bar's current appearance keeps
            // whatever Liquid Glass is doing behind and changes only the
            // marks on top of it.
            let appearance = (original ?? UITabBarAppearance())
            let updated = appearance.copy() as! UITabBarAppearance
            for item in [updated.stackedLayoutAppearance,
                         updated.inlineLayoutAppearance,
                         updated.compactInlineLayoutAppearance] {
                item.normal.iconColor = tint.withAlphaComponent(0.55)
                item.selected.iconColor = tint
            }
            guard bar.standardAppearance !== updated else { return }
            bar.standardAppearance = updated
            bar.scrollEdgeAppearance = updated
        }

        private func tabBarController() -> UITabBarController? {
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let controller = next as? UITabBarController { return controller }
                responder = next
            }
            return window?.rootViewController as? UITabBarController
        }
    }
}
