import SwiftUI
import UIKit

enum StrataTab: String, CaseIterable {
    case tower = "Wins"
    /// **Crews, a tab of their own, right of Wins** (the owner, 2026-10-13,
    /// from his phone: "the big one I want the crew to be its own tab on the
    /// right of the wins tab"). They lived behind a button in Wins' top
    /// right, which is the Journal's now. Only where crews are on.
    case crews = "Crews"
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
        case .crews: Image("TabCrews")
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
    /// **Icons only** (the owner, 2026-10-16: "no names under the tab at
    /// the bottom"). The words come off the bar a third time; the name stays
    /// for VoiceOver.
    ///
    /// **Names back, by a setting that is off** (the launch pass, 5½: "nobody
    /// has to guess what an icon means ... decide with research"). Apple's
    /// HIG asks for a label on every tab, NN/g finds icon-only navigation
    /// unclear, and older people misread unlabelled icons; the owner chose
    /// icons only the same day, so it waits for him in Settings, Show Tab
    /// Names (`TabNames`), off.
    @ViewBuilder
    var label: some View {
        if TabNames.shown {
            Label(rawValue, image: assetName)
                .labelStyle(.titleAndIcon)
        } else {
            Label(rawValue, image: assetName)
                .labelStyle(.iconOnly)
                .accessibilityLabel(rawValue)
        }
    }

    /// **The tab with the app's dot on it** (2026-10-13). A tab bar badge
    /// can only be the system's red circle or its grey one; the owner called
    /// the red one terrifying. The app's news is its own coral dot, drawn by
    /// hand (`NewsDot`), so it is drawn into the glyph: overlapping its top
    /// right with a clear ring cut round it, as he liked it ("I liked the
    /// overlapped look"), with the number of crews that have something new
    /// in it ("maybe a number in the middle"). Drawn as it is, not tinted,
    /// so the dot keeps its colour; the glyph is drawn in the bar's own ink
    /// for the appearance.
    func label(news count: Int, lit: Bool, scheme: ColorScheme) -> some View {
        Group {
            if count > 0 || lit, let marked = Self.marked(assetName, count: count, dark: scheme == .dark) {
                Label { Text(rawValue) } icon: { Image(uiImage: marked) }
            } else {
                Label(rawValue, image: assetName)
            }
        }
        .labelStyle(TabNameStyle())
        .accessibilityLabel(rawValue)
    }

    @MainActor private static var markedCache: [String: UIImage] = [:]

    /// The glyph in ink with the coral dot over its corner, and the count in
    /// it (nothing written for none: a dot alone for "go and look").
    @MainActor static func marked(_ name: String, count: Int, dark: Bool) -> UIImage? {
        let key = "\(name)|\(count)|\(dark)"
        if let hit = markedCache[key] { return hit }
        guard let glyph = UIImage(named: name) else { return nil }
        let size = glyph.size
        let written = count > 9 ? "9+" : count > 0 ? "\(count)" : ""
        // **Over the drawing's second head, all of it** (the owner,
        // 2026-10-13: "make sure the second head is completely covered,
        // right now it's like slipping out"). Measured off his drawing at
        // 84px: that head spans x 56 to 70 and y 9 to 30, five pixels clear
        // of the first. The numbered dot is centred on it and wide enough to
        // hide it whole; its left edge stops at the gap, so the clear ring
        // only grazes the first head's widest point instead of biting a
        // crescent out of it (seen in the first try). The plain dot is the
        // smallest that still covers it.
        let u = size.width / 84
        let side = (written.isEmpty ? 28 : 36) * u
        let centre = CGPoint(x: (written.isEmpty ? 63.5 : 67) * u, y: 19.5 * u)
        let dot = CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
        let canvas = CGRect(origin: .zero, size: size).union(dot).integral
        let format = UIGraphicsImageRendererFormat()
        format.scale = glyph.scale
        let ink = dark ? UIColor.white : UIColor.black
        let image = UIGraphicsImageRenderer(size: canvas.size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: -canvas.minX, y: -canvas.minY)
            glyph.withTintColor(ink, renderingMode: .alwaysOriginal).draw(in: CGRect(origin: .zero, size: size))
            // The ring of clear round the dot, so the two read apart.
            cg.setBlendMode(.clear)
            cg.addPath(NewsDotShape.cgPath(in: dot.insetBy(dx: -1.5 * u, dy: -1.5 * u)))
            cg.fillPath()
            cg.setBlendMode(.normal)
            cg.setFillColor(AppColors.notifyUI.cgColor)
            cg.addPath(NewsDotShape.cgPath(in: dot))
            cg.fillPath()
            guard !written.isEmpty else { return }
            let font = UIFont.systemFont(ofSize: side * 0.62, weight: .semibold)
            let words = NSAttributedString(string: written, attributes: [.font: font, .foregroundColor: UIColor.white])
            let box = words.size()
            words.draw(at: CGPoint(x: dot.midX - box.width / 2, y: dot.midY - box.height / 2))
        }.withRenderingMode(.alwaysOriginal)
        markedCache[key] = image
        return image
    }

    var assetName: String {
        switch self {
        case .tower: "TabWins"
        // A stand-in, drawn to the others' size and weight, until the owner
        // draws his own; his social doodle, at the others' size (his call).
        case .crews: "TabCrews"
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
        case .crews: "TabCrews"
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


/// **The bar in black over the camera, drawn** (the owner, 2026-10-16: "I
/// really want the bottom tabs to be black when you are on the camera, but I
/// hate the way it glitches the tabs and takes a while to come back").
///
/// The bar is the system's Liquid Glass and it samples what is behind it;
/// told to go dark it lags most of a second coming back, and that was the
/// jank. So the real bar stays as it is everywhere, and on the camera a
/// drawing of it in black stands exactly over it, measured from the real
/// one: its shape, its four pictures, the pill on the camera. It takes no
/// touch, so every tap is the real bar's. Leaving the camera it fades in a
/// fifth of a second over a bar that is already light, so nothing lags.
///
/// **Off until the owner has seen it** (his rule: camera changes go to him
/// first): `-strataDarkCameraBar` turns it on.
/// Whether the camera is showing a photograph just taken: the review stands
/// on the page in the phone's own appearance, so the black bar steps aside.
@MainActor @Observable
final class CameraReviewState {
    static let shared = CameraReviewState()
    var reviewing = false
}

struct CameraTabBarSkin: View {
    @State private var bar: CGRect?
    @State private var tabs: [(tab: StrataTab, button: CGRect, picture: CGRect)] = []

    /// **On** (the owner, 2026-10-16, asked: "Turn it on"). It was behind
    /// `-strataDarkCameraBar` until he had seen it; `-strataLightCameraBar`
    /// puts the plain bar back, for comparing.
    static var isOn: Bool {
        #if DEBUG
        return !ProcessInfo.processInfo.arguments.contains("-strataLightCameraBar")
        #else
        return true
        #endif
    }

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            if let bar {
                ZStack(alignment: .topLeading) {
                    // **Black under it, to the foot of the screen** (the owner,
                    // 2026-10-16: "make that background black, not white, on
                    // the camera"): drawn here with the bar, so the real bar's
                    // ground never changes and leaving never lags.
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geo.size.width + 2, height: geo.size.height - (bar.minY - origin.y) + 40)
                        .offset(x: -1, y: bar.minY - origin.y - 40)
                    Capsule()
                        .fill(Color(white: 0.1))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: GridConstants.strokeThin))
                        .frame(width: bar.width, height: bar.height)
                        .offset(x: bar.minX - origin.x, y: bar.minY - origin.y)
                    ForEach(tabs, id: \.tab) { item in
                        if item.tab == .camera {
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: item.button.width, height: item.button.height)
                                .offset(x: item.button.minX - origin.x, y: item.button.minY - origin.y)
                        }
                        Image(item.tab.assetName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.white.opacity(item.tab == .camera ? 1 : 0.6))
                            .frame(width: item.picture.width, height: item.picture.height)
                            .offset(x: item.picture.minX - origin.x, y: item.picture.minY - origin.y)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // Again until the bar is there: opening on the camera, it is laid
        // out a moment after this view.
        .task {
            for _ in 0..<20 {
                measure()
                if bar != nil, tabs.count == StrataTab.allCases.count { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func measure() {
        bar = TabGlyph.barFrame()
        tabs = StrataTab.allCases.compactMap { tab in
            TabGlyph.frames(of: tab).map { (tab, $0.button, $0.picture) }
        }
    }
}


/// **Show Tab Names**, a setting, off by default (see `StrataTab.label`).
enum TabNames {
    static let key = "tabNamesShown"
    static var shown: Bool { UserDefaults.standard.bool(forKey: key) }
}

/// The tab's word under its drawing when Show Tab Names is on.
struct TabNameStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        if TabNames.shown {
            VStack(spacing: 2) { configuration.icon; configuration.title }
        } else {
            configuration.icon
        }
    }
}
