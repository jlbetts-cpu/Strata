import SwiftUI

/// Controls made of the thing the app is made of.
///
/// The audit in `docs/design-audit.md` found two design languages running side
/// by side: blocks on Wins and Camera, stock iOS everywhere else — grouped
/// lists, segmented controls, circular swatches. Every screen was built from
/// one or the other, and the seam showed the moment you changed tabs.
///
/// One rule replaces that: **every surface you can act on is a block, or it
/// gets out of the way.** These are the blocks. Labels, fields, dividers and
/// backgrounds are the getting out of the way, and there is no third category.
///
/// Both types take their radius from `GridConstants.blockCornerRadius(forCell:)`,
/// so a 34pt chip and an 86pt tower block are the same object at two sizes
/// rather than two shapes that happen to be rounded.

// MARK: - A block at control size

/// A block you can pick.
///
/// Selected it is the real surface — colour, rim, frosted band. Unselected it
/// is the same shape held back, because a control that is not chosen has not
/// happened yet, and colour in this app means something happened.
struct BlockChip<Label: View>: View {
    let category: HabitCategory
    let isSelected: Bool
    var side: CGFloat = 34
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    init(category: HabitCategory,
         isSelected: Bool,
         side: CGFloat = 34,
         action: @escaping () -> Void,
         @ViewBuilder label: @escaping () -> Label = { EmptyView() }) {
        self.category = category
        self.isSelected = isSelected
        self.side = side
        self.action = action
        self.label = label
    }

    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: side) }

    var body: some View {
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            ZStack {
                BlockSurface(cornerRadius: radius,
                             scale: side / GridConstants.blockReferenceCell) {
                    category.style.baseColor
                }
                .opacity(isSelected ? 1 : 0)

                // Held back: the same shape, drawn as the slot it would fill.
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(category.style.baseColor.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(category.style.baseColor.opacity(0.40),
                                          lineWidth: 1.4 * (side / GridConstants.blockReferenceCell) * 2.6)
                    }
                    .opacity(isSelected ? 0 : 1)

                label()
                    .foregroundStyle(isSelected ? .white : category.style.baseColor)
            }
            .frame(width: side, height: side)
            // Chosen sits forward. A selected control that is merely a
            // different colour reads as a state; one that is also nearer reads
            // as a choice.
            .scaleEffect(isSelected ? 1 : 0.88)
            .animation(GridConstants.motionSnappy, value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - The slot a block would sit in

/// A recess: the shape of a block, with no block in it.
///
/// This is the tower's empty slot, borrowed for everything that holds input —
/// search fields, photo wells, any container asking to be filled. It is the
/// honest container for this app: a well is a place something goes, and the
/// thing that goes in a Strata well is a block.
///
/// It is NOT the frosted, white-rimmed treatment CLAUDE.md reserves for
/// blocks. A recess is the absence of that: a slightly darker ground and a
/// hairline, nothing lit and nothing floating.
struct BlockWell<Content: View>: View {
    var cell: CGFloat = GridConstants.blockReferenceCell
    var isFocused: Bool = false
    @ViewBuilder var content: () -> Content

    private var radius: CGFloat { GridConstants.blockCornerRadius(forCell: cell) }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        content()
            .background {
                shape.fill(AppColors.warmBlack.opacity(isFocused ? 0.055 : 0.035))
            }
            .overlay {
                shape.strokeBorder(
                    AppColors.warmBlack.opacity(isFocused ? 0.16 : 0.09),
                    lineWidth: 1
                )
            }
            .animation(GridConstants.motionSnappy, value: isFocused)
    }
}

// MARK: - Size, as the shape it is

/// The three block sizes, drawn at true proportion.
///
/// It replaced a segmented control reading "Quick / Regular / Deep". Those are
/// words for shapes, on a screen whose whole subject is shapes — and the tower
/// already teaches the mapping by letting you drag the slot out into the size
/// you want. Teaching it twice, in two languages, is how an app stops feeling
/// like one thing.
struct BlockSizePicker: View {
    @Binding var size: BlockSize
    var category: HabitCategory
    /// The side of a 1x1 at this scale.
    var unit: CGFloat = 26

    private let gap: CGFloat = 4

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ForEach(BlockSize.allCases, id: \.self) { option in
                let w = CGFloat(option.columnSpan) * unit + CGFloat(option.columnSpan - 1) * gap
                let h = CGFloat(option.rowSpan) * unit + CGFloat(option.rowSpan - 1) * gap
                Button {
                    HapticsEngine.lightTap()
                    size = option
                } label: {
                    ZStack {
                        BlockSurface(
                            cornerRadius: GridConstants.blockCornerRadius(forCell: unit),
                            scale: unit / GridConstants.blockReferenceCell
                        ) { category.style.baseColor }
                            .opacity(size == option ? 1 : 0)

                        RoundedRectangle(cornerRadius: GridConstants.blockCornerRadius(forCell: unit),
                                         style: .continuous)
                            .strokeBorder(AppColors.warmBlack.opacity(0.22),
                                          lineWidth: 1.4 * (unit / GridConstants.blockReferenceCell) * 2.6)
                            .opacity(size == option ? 0 : 1)
                    }
                    .frame(width: w, height: h)
                    .scaleEffect(size == option ? 1 : 0.94)
                    .animation(GridConstants.motionSnappy, value: size)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name(option))
                .accessibilityAddTraits(size == option ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
        .frame(height: unit * 2 + gap)
    }

    private func name(_ size: BlockSize) -> String {
        switch size {
        case .small:  return "Small, one by one"
        case .medium: return "Medium, two by one"
        case .hard:   return "Large, two by two"
        }
    }
}
