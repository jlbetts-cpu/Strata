import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Wins"
    case camera = "Camera"
    case memories = "Memories"

    /// The glyph for this tab, in the state it is in.
    ///
    /// **One function, because there were three answers to this.** The enum
    /// carried an `icon` and a `selectedIcon`; `MainAppView` then typed both
    /// strings inline for Wins and for Camera and passed the bare `icon` for
    /// Memories. So `selectedIcon` was read by nothing at all, and Memories is
    /// the one tab that never fills when you are on it.
    /// `docs/research/visual-cohesion.md` section 4.3 found the same thing by
    /// measurement ("The Memories tab never fills"), and the rule it sets is the
    /// app's: filled means selected, outline means not, everywhere.
    ///
    /// Filled and hollow are one decision about one glyph, so they live in one
    /// place. Two properties plus a literal at the call site is three places for
    /// it, which is how they came apart.
    ///
    /// `docs/design-system-future.md` section 10, rule 8: never two solutions to
    /// the same problem on one screen.
    func icon(selected: Bool) -> String {
        switch self {
        case .tower: return selected ? "square.stack.fill" : "square.stack"
        case .camera: return selected ? "camera.fill" : "camera"
        case .memories: return selected ? "photo.stack.fill" : "photo.stack"
        }
    }

    /// The hollow glyph, for the places a tab is named outside the tab bar where
    /// there is no selection to reflect.
    var icon: String { icon(selected: false) }
}
