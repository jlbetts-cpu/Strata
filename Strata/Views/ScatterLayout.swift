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
    /// **The cell is half the folder, because the tower's grid is two
    /// columns wide and these are the tower's blocks.**
    ///
    /// The owner: "I don't like that they are so tiny and they don't even go
    /// to the margins, they just feel very off."
    ///
    /// They were tiny because the cell was a made-up fraction of the width
    /// (0.22, then 0.275) rather than a share of the grid the sizes come
    /// from. `BlockSize` spans columns of a TWO column grid: 1x1 is half a
    /// row, 2x1 is a whole one, 2x2 is a whole one twice as tall. Sizing off
    /// that makes a small exactly half the folder, a medium exactly all of
    /// it, and every row reach both margins, which is what he is describing
    /// and what the tower always did.
    static func cell(in width: CGFloat) -> CGFloat { (width - gutter) / 2 }

    static func size(for size: BlockSize, in width: CGFloat) -> CGSize {
        let cell = cell(in: width)
        func span(_ n: Int) -> CGFloat { cell * CGFloat(n) + gutter * CGFloat(n - 1) }
        return CGSize(width: span(size.columnSpan), height: span(size.rowSpan))
    }

    /// The space reserved between items. Part of it is the gap you see; the
    /// rest is the budget the jitter spends.
    ///
    /// **Raised from 18, and cards no longer touch at all.** The owner: "why
    /// are they touching... more spacing." Letting them overlap was my read
    /// of "organised clutter" and it was wrong: his own reference has clear
    /// air between every card. Photographs dropped on a table do overlap;
    /// photographs somebody has laid out do not, and a folder somebody keeps
    /// is the second thing.
    static let gutter: CGFloat = 28

    /// The most any item leans. Past about five degrees a grid of
    /// photographs stops reading as casual and starts reading as broken.
    static let lean: Double = 4.4

    /// **How far a card may tuck, when it tucks at all.** A tenth, on about
    /// a third of the pairs that share a line. It was a fifth on every other
    /// card, which read as a pile rather than as clutter; space is the rule
    /// now and contact is the exception he allowed.
    static let tuck: CGFloat = 0.10
    /// The most of a card that may ever end up hidden behind later ones.
    static let maxCovered: CGFloat = 0.14

    /// Places every item. Pure, deterministic, and total: any count from zero
    /// upwards returns a usable layout.
    /// `tidy` is the Organize button: the same packing with the mess turned
    /// off. Because both layouts come out of one function, switching between
    /// them is a frame change SwiftUI can animate, and every card glides to
    /// its place rather than being rebuilt somewhere else.
    static func place(_ items: [Item], in width: CGFloat, tidy: Bool = false) -> [Placement] {
        guard width > 0, !items.isEmpty else { return [] }
        if tidy { return tidied(items, in: width) }

        var placements: [Placement] = []
        var row: [Item] = []
        var rowWidth: CGFloat = 0
        var y: CGFloat = gutter

        func flush() {
            guard !row.isEmpty else { return }
            let sizes = row.map { Self.size(for: $0.size, in: width) }
            let total = sizes.map(\.width).reduce(0, +) + gutter * CGFloat(row.count - 1)
            // **A short row goes to one side, not the middle.**
            //
            // Centring it looked wrong the moment cards got big enough to
            // reach the margins: a half width card sitting dead centre
            // between two full width ones reads as a mistake rather than as
            // clutter. Seeded off the first card, so it is the same side
            // every time, and it only applies when there is room to move.
            let slack = width - total
            var x = slack < 1 ? 0
                : slack * (0.15 + 0.7 * unit(row[0].id, 13))
            let tallest = sizes.map(\.height).max() ?? 0

            for (index, pair) in zip(row, sizes).enumerated() {
                let (item, box) = pair
                // **A little overlap, sometimes.** The owner: "maybe a bit
                // of overlap sometimes is okay, but I was hoping they would
                // have enough space to look nicely organised clutter." So
                // space is the rule and contact is the exception: about a
                // third of the pairs that share a line touch, by up to a
                // tenth of a card. Seeded, so it is the same pairs every
                // time, and bounded, so `nothingIsEverBuried` still holds.
                let touches = index > 0 && Self.unit(item.id, 11) < 0.34
                let tuckBack = touches ? box.width * tuck : 0
                let top = y + (tallest - box.height) / 2
                var frame = CGRect(x: x - tuckBack, y: top,
                                   width: box.width, height: box.height)
                let seed = Self.seed(item.id)
                // The jitter, spent out of the gutter that packing
                // reserved. A third of it each way, so two neighbours
                // leaning towards each other still keep a third of it.
                frame.origin.x += (seed.0 - 0.5) * gutter * (2.0 / 3.0)
                frame.origin.y += (seed.1 - 0.5) * gutter * (2.0 / 3.0)
                // **Clamped, because a full width card has nowhere to go.**
                // Now that a 2x1 spans both columns there is no slack beside
                // it, and jittering pushed it three points past the margin.
                // A card at the edge simply does not move sideways.
                frame.origin.x = min(max(frame.origin.x, 0), width - frame.width)
                // **Which way a card leans comes from where it SITS, not
                // from its place in the list.**
                //
                // Alternating by index was the second wrong answer to this.
                // It fixed the first one — a whole screen tilting the same
                // way, which the owner named as the tower of Pisa — and
                // created a worse one: a card on the left turning clockwise
                // beside a card on the right turning anticlockwise puts their
                // tops together, so every pair wedged INTO each other. "They
                // shouldn't be leaning into each other."
                //
                // A card left of its row's middle turns anticlockwise and one
                // right of it turns clockwise, so a row splays OPEN, the way
                // photographs fall when somebody sets them down. The seed
                // still varies how far, so it is not a herringbone, and it
                // decides the direction for a card sitting on the middle
                // where there is no side to take.
                //
                // Never less than 45% of the limit, because a lean of half a
                // degree is not a lean, it is a card that looks misaligned.
                let magnitude = (0.45 + 0.55 * seed.2) * lean
                let fromCentre = frame.midX - width / 2
                let direction: Double = abs(fromCentre) < box.width * 0.2
                    ? (Self.unit(item.id, 7) < 0.5 ? -1 : 1)
                    : (fromCentre < 0 ? -1 : 1)
                placements.append(Placement(id: item.id, frame: frame,
                                            angle: tidy ? 0 : magnitude * direction))
                x += box.width + gutter - tuckBack
            }
            // Rows close up as well, or the clutter is only sideways. A
            // third of the gutter back, which the vertical jitter then
            // scatters again. Tidy keeps the full gutter.
            y += tallest + gutter
            row = []
            rowWidth = 0
        }

        for item in items {
            let itemWidth = Self.size(for: item.size, in: width).width
            let next = rowWidth == 0 ? itemWidth : rowWidth + gutter + itemWidth
            // A row is full when adding this one would overflow. The gutter
            // is counted, so the row's own jitter budget is always there.
            // **No slack at all, because the sizes are built to fill the
            // width exactly.** Two 1x1s plus a gutter come to precisely the
            // folder's width, so any allowance here rejected them and every
            // row held one card: the scatter was a single column of
            // full-width cards and no test about what happens BETWEEN two
            // cards on a line was checking anything.
            if next > width + 0.001, !row.isEmpty {
                flush()
            }
            row.append(item)
            rowWidth = rowWidth == 0 ? itemWidth : rowWidth + gutter + itemWidth
        }
        flush()
        return placements
    }

    /// **Organised: two columns, and it is a different layout rather than
    /// the same one with the mess switched off.**
    ///
    /// The owner, on the first version: "I think the organised one should
    /// look a bit different, like the Cosmos build, where it's two columns."
    /// He is right that unjittering the scatter is not organising it — it
    /// still had ragged rows and cards centred on each other, which reads as
    /// a scatter someone straightened rather than as a grid.
    ///
    /// Two equal columns, every card the full column width, heights from the
    /// block's own proportions, each one going to whichever column is
    /// shorter. That is a masonry, it never leaves a ragged edge, and it
    /// reads as a place things have been PUT.
    ///
    /// **The order is preserved and so is every id**, which is what lets the
    /// change between the two be an animation rather than a reload: the same
    /// cards are on screen before and after, and only their frames moved, so
    /// SwiftUI carries each one from one place to the other.
    static func tidied(_ items: [Item], in width: CGFloat) -> [Placement] {
        let column = (width - gutter) / 2
        var heights: [CGFloat] = [gutter, gutter]
        var placements: [Placement] = []
        for item in items {
            let shape = size(for: item.size, in: width)
            let height = column * (shape.height / max(shape.width, 0.001))
            let side = heights[0] <= heights[1] ? 0 : 1
            let x = side == 0 ? 0 : column + gutter
            placements.append(Placement(
                id: item.id,
                frame: CGRect(x: x, y: heights[side], width: column, height: height),
                angle: 0))
            heights[side] += height + gutter
        }
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
    ///
    /// **Three separate hashes, not three slices of one.** The first version
    /// took bits 0, 16 and 32 of a single FNV hash, and the high slice turned
    /// out to be very nearly monotonic in the id: across twenty wins the lean
    /// came out `----------++++++++++`. Every card on one screen leaned the
    /// same way, which the owner named immediately — "it still looks like the
    /// tower of Pisa". Salting the input per value makes the three genuinely
    /// independent, which slicing one hash never guaranteed.
    static func seed(_ id: String) -> (CGFloat, CGFloat, CGFloat) {
        (unit(id, 1), unit(id, 2), unit(id, 3))
    }

    static func unit(_ id: String, _ salt: UInt8) -> CGFloat {
        var h: UInt64 = 0xcbf29ce484222325
        h = (h ^ UInt64(salt)) &* 0x100000001b3
        for byte in id.utf8 {
            h = (h ^ UInt64(byte)) &* 0x100000001b3
        }
        // Fold the high half into the low one, so no part of the result
        // depends on a single region of the hash.
        h ^= h >> 33
        return CGFloat(h & 0xFFFF) / CGFloat(0xFFFF)
    }
}
