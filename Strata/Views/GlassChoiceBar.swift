import SwiftUI

/// **A row of words on Liquid Glass, the chosen one on a pill that slides**
/// (the owner, 2026-10-15: "in the plan the bar doesnt use liquid glass
/// thats a key indicator ... if someone goes through a flow very similar it
/// should feel the same"). The Plan's days and the add sheet's When were
/// plain words on the page, cut by the margin, while every other control on
/// both sheets stands on glass. This is the segmented bar Photos' Years,
/// Months and All, and Music's library switch, are made of on iOS 26: one
/// glass capsule, and inside it the chosen word on a quiet pill that moves
/// to the next one as one object.
///
/// It scrolls when the words outrun it, and fades at whichever end has more.
struct GlassChoiceBar<Item: Hashable>: View {
    let items: [Item]
    let chosen: Item
    var title: (Item) -> String
    var spoken: (Item) -> String
    /// Something is there: a dot under the word, never a number.
    var dot: (Item) -> Bool = { _ in false }
    var choose: (Item) -> Void
    /// **Equal shares of the width, nothing scrolls**: the segmented shape,
    /// for a few words that always fit (Quick, Regular, Deep; Day, Week,
    /// Month), so every choice of one-of-a-few in the app is this one bar.
    var fills = false

    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var height: CGFloat { GlassIconButton.defaultSide }
    /// The chosen word's lens: white on the light page, a raised grey on the
    /// dark one (dark on dark: never white there).
    static var lens: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.16) : UIColor(white: 1, alpha: 0.95)
        })
    }
    private static var inset: CGFloat { 4 }

    var body: some View {
        if fills {
            HStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    word(item).frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Self.inset)
            .frame(height: Self.height)
            .clipShape(Capsule(style: .continuous))
            .glassCapsule(onPage: true, interactive: false)
            .overlay(Capsule(style: .continuous).strokeBorder(AppColors.quietFill, lineWidth: 1))
        } else {
            scrolling
        }
    }

    private var scrolling: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        word(item).id(item)
                    }
                }
                .padding(.horizontal, Self.inset)
            }
            .edgeFade(GridConstants.gapItem)
            // Opened on the chosen word, and kept in view as it changes.
            .onAppear { proxy.scrollTo(chosen, anchor: .center) }
            .onChange(of: chosen) { _, now in
                withAnimation(reduceMotion ? nil : GridConstants.motionSnappy) { proxy.scrollTo(now, anchor: .center) }
            }
        }
        .frame(height: Self.height)
        .clipShape(Capsule(style: .continuous))
        // Holds buttons rather than being one: not interactive glass, which
        // would take their taps (`glassCapsule`).
        .glassCapsule(onPage: true, interactive: false)
        // The same hairline the writing fields have (`glassField`).
        .overlay(Capsule(style: .continuous).strokeBorder(AppColors.quietFill, lineWidth: 1))
    }

    private func word(_ item: Item) -> some View {
        let on = item == chosen
        return Button {
            guard !on else { return }
            HapticsEngine.tick()
            withAnimation(reduceMotion ? GridConstants.crossFade : GridConstants.motionSnappy) { choose(item) }
        } label: {
            Text(title(item))
                .font(Typography.headerSmall)
                .foregroundStyle(on ? AppColors.inkPrimary : AppColors.inkSecondary)
                .lineLimit(1)
                .padding(.horizontal, GridConstants.gapItem)
                .frame(minWidth: 44, maxWidth: fills ? .infinity : nil)
                .frame(height: Self.height - Self.inset * 2)
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(on ? AppColors.inkPrimary : AppColors.inkTertiary)
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 3)
                        .opacity(dot(item) ? 1 : 0)
                }
                .background {
                    if on {
                        // The chosen word on a bright lens, as iOS's own
                        // segmented thumb sits on its glass track: a grey
                        // pill read as a grey bar (the owner, 2026-10-15).
                        Capsule(style: .continuous)
                            .fill(Self.lens)
                            .overlay(Capsule(style: .continuous).strokeBorder(AppColors.quietFill, lineWidth: 0.5))
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
                .frame(minHeight: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressWord)
        .accessibilityLabel(spoken(item))
        .accessibilityValue(dot(item) ? "Has plans" : "")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}
