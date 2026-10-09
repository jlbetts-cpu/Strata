import SwiftUI
import UIKit

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
    ///
    /// **Each says what its tab is** (the owner, 2026-10-03: "make sure icons
    /// on the bottom are clear... they kinda help understand what the tab is
    /// for", and "I only want sf symbols"). Wins was `square.stack`, a pile of
    /// cards, and Memories `photo.stack`, a pile of photos; neither named its
    /// tab. Wins is the house, where the app opens (his call, over the trophy
    /// he first picked: a trophy reads as a big achievement, not a small daily
    /// one); Memories is the calendar the page
    /// opens on.
    ///
    /// **And now they are his drawings** (the owner, 2026-10-06, reversing
    /// "only sf symbols" on seeing Luma: a characterful set on the bottom
    /// tabs, Apple's own glyphs up top, "instantly adds personality to the
    /// app while keeping everything clean"; his pick, "You draw them"). Three
    /// filled shapes he drew in Procreate, a house with a smile, a camera, a
    /// calendar, made by `docs/tab-icons/make_tab_icons.py`: his white marks
    /// turned into true holes, so the bar's tint reaches every edge.
    ///
    /// **Filled in both states, as Luma's are**, so `selected` no longer
    /// changes the drawing: the bar's tint and its glass pill say which tab
    /// you are on. The research behind the choice: a heavy filled set beside
    /// thin SF Symbols reads as a decision, an outline set reads as SF at the
    /// wrong weight (`docs/research` icon notes, 2026-10-06).
    func image(selected: Bool) -> Image {
        switch self {
        case .tower: Image("TabWins")
        case .camera: Image("TabCamera")
        case .memories: Image("TabMemories")
        }
    }

    /// The tab as the bar shows it: his drawing with its name under it, in
    /// the system's own type (the owner, 2026-10-06, the words back), grey
    /// when you are not on it, as Luma's are.
    ///
    /// **One picture, drawn here, not the bar's own icon and title.** iOS
    /// 26's glass bar draws an idle tab's word in full ink and ignores every
    /// way of saying otherwise (`unselectedItemTintColor`, the item
    /// appearance, `UITabBarItem` title attributes, a coloured `Text`; each
    /// measured, none moved a pixel). So the drawing and its word are drawn
    /// together and handed over as the icon: the tab you are on as a
    /// template, so the bar's tint draws it; an idle one already grey. The
    /// name still reaches VoiceOver.
    /// **The bar's own label again** (the owner, 2026-10-08: "make sure it
    /// works natively again"; the tabs "flicker back to light or dark"). His
    /// drawing as the tab's image and the tab's name as its title, handed to
    /// the system, which draws the selection pill, the tint, the press and
    /// the scheme. The flattened picture (`picture(selected:scheme:)`) kept
    /// idle words grey, which iOS 26's bar will not do on its own, at the
    /// price of being redrawn for every scheme change and of the bar's own
    /// selection never animating; the native bar is the better trade. The
    /// picture is kept for the onboarding's drawing of the bar.
    var label: some View {
        Label(rawValue, image: assetName)
    }

    var assetName: String {
        switch self {
        case .tower: "TabWins"
        case .camera: "TabCamera"
        case .memories: "TabMemories"
        }
    }

    /// The word's size and weight: the bar's own, measured off its titles.
    static let wordFont = UIFont.systemFont(ofSize: 10, weight: .medium)
    static let glyph: CGFloat = 28
    static let gap: CGFloat = 1

    func picture(selected: Bool, scheme: ColorScheme) -> UIImage {
        let name = switch self {
        case .tower: "TabWins"
        case .camera: "TabCamera"
        case .memories: "TabMemories"
        }
        let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        let ink = selected ? UIColor.black : AppColors.tabIdle.resolvedColor(with: traits)
        let word = NSAttributedString(string: rawValue, attributes: [.font: Self.wordFont, .foregroundColor: ink])
        let wordSize = word.size()
        let size = CGSize(width: max(Self.glyph, ceil(wordSize.width)),
                          height: Self.glyph + Self.gap + ceil(wordSize.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let icon = (UIImage(named: name) ?? UIImage()).withTintColor(ink, renderingMode: .alwaysOriginal)
            icon.draw(in: CGRect(x: (size.width - Self.glyph) / 2, y: 0, width: Self.glyph, height: Self.glyph))
            word.draw(at: CGPoint(x: (size.width - wordSize.width) / 2, y: Self.glyph + Self.gap))
        }
        return image.withRenderingMode(selected ? .alwaysTemplate : .alwaysOriginal)
    }

    // **`var icon` is deleted** (2026-10-01). It was the hollow shorthand "for
    // the places a tab is named outside the tab bar", and the one place that
    // was true of — the drawn tab bar inside the onboarding device frame —
    // calls `icon(selected:)` properly. Its only other caller was the real tab
    // bar, which passed it for Memories and so could never fill that glyph.
    // A shorthand whose only user was a bug.
}
