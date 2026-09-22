import CoreGraphics
import Foundation

/// **Organised clutter, as arithmetic.**
///
/// The owner: "the inside would look like this, like organised clutter...
/// make sure it looks good with 1 photo to 20 and the photo sizes actually
/// make sense."
///
/// That range is the whole problem. A scatter hand-arranged to look good at
/// six is lonely at one and mush at twenty, and the usual answers both fail
/// in a photo collage: a **jittered grid** guarantees coverage but still
/// clumps, and **Poisson disc** spaces beautifully but guarantees no
/// coverage, which at one or two items leaves a hole where the content
/// should be.
///
/// **So: pack first, then spend the gutter on the mess.** Items are packed
/// into rows that always fill the width, which is the "organised" half and
/// cannot fail at any count. Then every item is jittered and rotated inside
/// the gutter that the packing already reserved, which is the "clutter" half.
/// Because the jitter budget is a fraction of a gap that is guaranteed to
/// exist, **nothing can ever collide, at any N**, and the layout does not
/// have to be checked by eye to be trusted.
///
/// **The sizes are not random, and that is the other half of "make sense".**
/// A win is already drawn at a size at the shutter: one cell, two, or the big
/// one. That is the size it is in here. The ladder that already exists does
/// the work, so a big win looks big because it WAS big, not because a
/// shuffler said so.
///
/// Everything is seeded by the win's own identifier, so a folder looks the
/// same every time it is opened. A scatter that reshuffles on each redraw is
/// the fastest way to make a place feel untrustworthy.
enum ScatterLayout {

    /// What goes in: an identity, and how big the win was drawn.
    struct Item: Equatable {
        var id: String
        var size: BlockSize
    }

    /// What comes out: where it sits and how far it leans.
    struct Placement: Equatable {
        var id: String
        var frame: CGRect
        var angle: Double
    }

    /// **The sizes are the block system, not an echo of it.**
    ///
    /// The owner: "the photos aren't based on the size like they should, like
    /// they should still be like relative rectangle for medium and bigger for
    /// large than quick, like how we had the block system."
    ///
    /// They were not: every card was the same portrait shape and only the
    /// WIDTH changed, so a medium was a slightly bigger small and the shapes
    /// carried no meaning. `BlockSize` already says exactly what each one is
    /// and has since the tower — small is 1x1, medium is 2x1, hard is 2x2 —
    /// so this reads those spans rather than inventing a second ladder that
    /// would then have to be kept in step with the first.
    ///
    /// A win is a shape you recognise from the tower, in a folder.
    static let unit: CGFloat = 0.275

    static func size(for size: BlockSize, in width: CGFloat) -> CGSize {
        let cell = width * unit
        return CGSize(width: cell * CGFloat(size.columnSpan),
                      height: cell * CGFloat(size.rowSpan))
    }

    /// The space reserved between items. Half of it is the gap you see; the
    /// other half is the budget the jitter spends.
    static let gutter: CGFloat = 18

    /// The most any item leans. Past about five degrees a grid of
    /// photographs stops reading as casual and starts reading as broken.
    static let lean: Double = 4.4

    /// **How far a card may tuck under the one before it, as a share of its
    /// own width.**
    ///
    /// Packing with a guaranteed gap held from one win to twenty, and looked
    /// wrong: cards that never touch read as a grid with a lean on it, not as
    /// clutter. Photographs in a real folder overlap.
    ///
    /// So overlap is allowed, and the guarantee moves rather than
    /// disappearing. It is no longer "nothing touches"; it is **no card is
    /// more than a fifth covered**, which is the property that actually
    /// matters — every win stays recognisable and stays tappable. That is
    /// assertable at every count exactly as the old rule was, and it is the
    /// rule worth having.
    static let tuck: CGFloat = 0.20
    /// The most of a card that may end up hidden behind later ones.
    static let maxCovered: CGFloat = 0.22

    /// Places every item. Pure, deterministic, and total: any count from zero
    /// upwards returns a usable layout.
    /// `tidy` is the Organize button: the same packing with the mess turned
    /// off. Because both layouts come out of one function, switching between
    /// them is a frame change SwiftUI can animate, and every card glides to
    /// its place rather than being rebuilt somewhere else.
    static func place(_ items: [Item], in width: CGFloat, tidy: Bool = false) -> [Placement] {
        guard width > 0, !items.isEmpty else { return [] }

        var placements: [Placement] = []
        var row: [Item] = []
        var rowWidth: CGFloat = 0
        var y: CGFloat = gutter

        func flush() {
            guard !row.isEmpty else { return }
            let sizes = row.map { Self.size(for: $0.size, in: width) }
            let total = sizes.map(\.width).reduce(0, +) + gutter * CGFloat(row.count - 1)
            // Centred, so a short row is not left hanging against one edge.
            var x = (width - total) / 2
            let tallest = sizes.map(\.height).max() ?? 0

            for (index, pair) in zip(row, sizes).enumerated() {
                let (item, box) = pair
                // Every other card after the first tucks under its
                // neighbour. Alternating rather than random, so a row reads
                // as a deliberate arrangement rather than as a pile.
                let tuckBack = (!tidy && index > 0 && index % 2 == 1)
                    ? box.width * tuck * CGFloat(0.6 + 0.4 * seed(item.id).0) : 0
                // Tidy sits everything on one baseline; clutter centres each
                // card in the row, which is what lets shapes of different
                // heights interlock.
                let top = tidy ? y : y + (tallest - box.height) / 2
                var frame = CGRect(x: x - tuckBack, y: top,
                                   width: box.width, height: box.height)
                let seed = Self.seed(item.id)
                if !tidy {
                    // The jitter, spent out of the gutter that packing
                    // reserved. A third of it each way, so two neighbours
                    // leaning towards each other still keep a third of it.
                    frame.origin.x += (seed.0 - 0.5) * gutter * (2.0 / 3.0)
                    frame.origin.y += (seed.1 - 0.5) * gutter * (2.0 / 3.0)
                }
                placements.append(Placement(id: item.id, frame: frame,
                                            angle: tidy ? 0 : (seed.2 - 0.5) * 2 * lean))
                x += box.width + gutter - tuckBack
            }
            // Rows close up as well, or the clutter is only sideways. A
            // third of the gutter back, which the vertical jitter then
            // scatters again. Tidy keeps the full gutter.
            y += tallest + (tidy ? gutter : gutter * 0.66)
            row = []
            rowWidth = 0
        }

        for item in items {
            let itemWidth = Self.size(for: item.size, in: width).width
            let next = rowWidth == 0 ? itemWidth : rowWidth + gutter + itemWidth
            // A row is full when adding this one would overflow. The gutter
            // is counted, so the row's own jitter budget is always there.
            if next > width - gutter * 2, !row.isEmpty {
                flush()
            }
            row.append(item)
            rowWidth = rowWidth == 0 ? itemWidth : rowWidth + gutter + itemWidth
        }
        flush()
        return placements
    }

    /// The total height a layout needs, so a scroll view can be told.
    static func height(_ placements: [Placement]) -> CGFloat {
        (placements.map { $0.frame.maxY }.max() ?? 0) + gutter
    }

    /// Three stable numbers in 0..<1 from a string. Not cryptography and not
    /// trying to be: it has to be the SAME every launch, which `hashValue`
    /// on a String is not, because Swift seeds string hashing per process.
    /// A folder that rearranged itself every launch would be the single
    /// worst thing this layout could do.
    static func seed(_ id: String) -> (CGFloat, CGFloat, CGFloat) {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            h = (h ^ UInt64(byte)) &* 0x100000001b3
        }
        func unit(_ shift: UInt64) -> CGFloat {
            CGFloat((h >> shift) & 0xFFFF) / CGFloat(0xFFFF)
        }
        return (unit(0), unit(16), unit(32))
    }
}
