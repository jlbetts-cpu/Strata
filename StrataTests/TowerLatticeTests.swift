import Testing
import SwiftUI
@testable import Strata

/// **The lattice has to be the tower's own grid, not a pattern that looks
/// like it.**
///
/// The owner asked for structure behind the blocks that helps somebody
/// understand the tower. It only does that while every cell is exactly where
/// a block would land; a lattice a few points out of step is a second grid on
/// the page, which is worse than none. Screenshots do not catch four points,
/// and the numbers do.
@Suite("The tower's lattice")
struct TowerLatticeTests {

    private let cell: CGFloat = 86
    private let spacing = GridConstants.spacing
    private var columns: Int { GridConstants.columnCount }

    private func shape() -> TowerLatticeShape {
        TowerLatticeShape(cellSize: cell, spacing: spacing, columns: columns)
    }

    /// Blocks are placed with `blockFrame`, then flipped so row 0 is on the
    /// ground. A lattice cell has to land on the same rectangle.
    ///
    /// **Proven able to fail**: measuring the lattice down from the top
    /// instead of up from the bottom moves every cell by the remainder of
    /// the height over the pitch, and this goes red at any height that is not
    /// a whole number of rows.
    @Test("Every cell is where a block would land")
    func cellsSitOnTheBlockGrid() {
        // A height that is deliberately NOT a whole number of rows.
        let height: CGFloat = 517
        let rect = CGRect(x: 0, y: 0, width: GridConstants.gridWidth(cellSize: cell), height: height)
        let rects = shape().cellRects(in: rect)
        #expect(!rects.isEmpty)

        for (index, cellRect) in rects.enumerated() {
            let column = index % columns
            let row = index / columns
            let frame = GridConstants.blockFrame(column: column, row: 0,
                                                 columnSpan: 1, rowSpan: 1, cellSize: cell)
            #expect(abs(cellRect.minX - frame.minX) < 0.01,
                    "column \(column) starts at \(cellRect.minX), a block starts at \(frame.minX)")
            // Row 0 sits on the ground, row 1 one pitch above it, and so on.
            let expectedBottom = height - CGFloat(row) * (cell + spacing)
            #expect(abs(cellRect.maxY - expectedBottom) < 0.01,
                    "row \(row) ends at \(cellRect.maxY) rather than \(expectedBottom)")
            #expect(abs(cellRect.width - cell) < 0.01)
            #expect(abs(cellRect.height - cell) < 0.01)
        }
    }

    /// The lattice is exactly as wide as the tower, so its right-hand column
    /// ends on the same margin the blocks do rather than a gutter short of it.
    @Test("The lattice is the tower's width, to the point")
    func theLatticeIsTheTowersWidth() {
        let width = GridConstants.gridWidth(cellSize: cell)
        let rect = CGRect(x: 0, y: 0, width: width, height: 400)
        let rects = shape().cellRects(in: rect)
        let right = rects.map(\.maxX).max() ?? 0
        #expect(abs(right - width) < 0.01,
                "the lattice reaches \(right) and the tower reaches \(width)")
    }

    /// A field of cells at the token's own strength was a checkerboard when
    /// it was photographed. This pins the decision, not the taste: whatever
    /// the number becomes, it stays under half of `quietFill`.
    @Test("An empty cell stays quieter than a well")
    func theLatticeStaysQuiet() {
        #expect(TowerLattice.strength > 0, "an invisible lattice is not a lattice")
        #expect(TowerLattice.strength <= 0.5,
                "at \(TowerLattice.strength) of quietFill the cells compete with the blocks")
    }

    /// Nothing is drawn for a tower that has not been measured yet, rather
    /// than a divide by zero or an endless row of cells.
    @Test("An unmeasured tower draws nothing")
    func zeroSizeDrawsNothing() {
        let empty = TowerLatticeShape(cellSize: 0, spacing: spacing, columns: columns)
        #expect(empty.cellRects(in: CGRect(x: 0, y: 0, width: 300, height: 300)).isEmpty)
    }

    // MARK: - The landing

    private func ripple(column: Int, row: Int, columnSpan: Int, rowSpan: Int) -> LatticeRipple {
        LatticeRipple(column: column, row: row, columnSpan: columnSpan, rowSpan: rowSpan,
                      colour: .red)
    }

    private func cells(_ r: LatticeRipple, front: CGFloat,
                       band: ClosedRange<CGFloat>, in rect: CGRect) -> [CGRect] {
        RippleCells(front: front, band: band, ripple: r,
                    cellSize: cell, spacing: spacing, columns: columns).litCells(in: rect)
    }

    /// **The ring starts where the block is, measured up from the ground.**
    ///
    /// The lattice is TALLER than the tower's grid by its overhang, so a ring
    /// placed by measuring down from the top of the lattice lands several rows
    /// above the block that caused it — and it would still look like a ripple,
    /// just one answering the wrong landing. This holds the origin against
    /// `GridConstants.blockFrame`, which is where the block itself is put.
    ///
    /// **Proven able to fail**: measuring from `rect.minY` instead of
    /// `rect.maxY` moves the origin by the whole height, and dropping the
    /// half-span term puts a 2x2's ring on its bottom-left corner.
    @Test("A ring starts at the centre of the block that caused it")
    func ringOriginIsTheBlocksCentre() {
        let pitch = cell + spacing
        // Deliberately not a whole number of rows, and deliberately taller
        // than the tower: that is what a lattice with its overhang is.
        let rect = CGRect(x: 0, y: 0, width: GridConstants.gridWidth(cellSize: cell), height: 913)

        for (column, row, columnSpan, rowSpan) in [(0, 0, 2, 2), (0, 0, 1, 1),
                                                   (2, 3, 2, 1), (1, 5, 1, 1)] {
            let r = ripple(column: column, row: row, columnSpan: columnSpan, rowSpan: rowSpan)
            let origin = RippleCells(front: 1, band: 0...1, ripple: r, cellSize: cell,
                                     spacing: spacing, columns: columns).origin(in: rect)
            let frame = GridConstants.blockFrame(column: column, row: row,
                                                 columnSpan: columnSpan, rowSpan: rowSpan,
                                                 cellSize: cell)
            // Across: the block's own frame, which is measured from the left
            // in both systems.
            #expect(abs(origin.x - frame.midX) < 0.01,
                    "\(columnSpan)x\(rowSpan) at column \(column) rings from x \(origin.x), the block sits at \(frame.midX)")
            // Up: row 0 stands on `rect.maxY` and every row is one pitch above
            // the one below it, so the block's centre is half its own height
            // above its bottom edge.
            let bottom = rect.maxY - CGFloat(row) * pitch
            #expect(abs(origin.y - (bottom - frame.height / 2)) < 0.01,
                    "\(columnSpan)x\(rowSpan) at row \(row) rings from y \(origin.y), the block's centre is \(bottom - frame.height / 2)")
        }
    }

    /// A cell the block is standing in is not an empty cell any more, so it
    /// is not part of the lattice and it does not react. Photographed without
    /// this, a landing read as a filled patch rather than as the surface
    /// answering around it.
    ///
    /// **Proven able to fail**: removing the footprint guard in `litCells`
    /// lights all four of a 2x2's own cells at a front of half a cell.
    @Test("The cells the block fills never react")
    func theBlocksOwnCellsDoNotReact() {
        let pitch = cell + spacing
        let rect = CGRect(x: 0, y: 0, width: GridConstants.gridWidth(cellSize: cell), height: 913)
        let r = ripple(column: 1, row: 1, columnSpan: 2, rowSpan: 2)
        // Every cell the block covers, as a rectangle.
        var covered: Set<String> = []
        for column in 1...2 {
            for row in 1...2 {
                let x = CGFloat(column) * pitch
                let top = rect.maxY - cell - CGFloat(row) * pitch
                covered.insert("\(Int(x.rounded()))/\(Int(top.rounded()))")
            }
        }
        // Walk the whole landing, both bands.
        var lit = 0
        for step in 0...200 {
            let front = TowerLattice.front(atPhase: Double(step) / 200, span: r.span)
            for band in [0...TowerLattice.frontBand, TowerLattice.frontBand...TowerLattice.backBand] {
                for rect in cells(r, front: front, band: band, in: rect) {
                    lit += 1
                    let key = "\(Int(rect.minX.rounded()))/\(Int(rect.minY.rounded()))"
                    #expect(!covered.contains(key),
                            "the block's own cell at \(key) lit up at front \(front)")
                }
            }
        }
        #expect(lit > 0, "nothing lit up at all, so this proves nothing")
    }

    /// **The ring has to be VISIBLE at some point in its life, and this is the
    /// test the bug got past.**
    ///
    /// The ring was driven by a `SpringKeyframe` that inherited 2000 cells a
    /// second of velocity from the 1ms keyframe before it, so the front spent
    /// every landing between 4 and 78 cells out against a reach of at most 5.
    /// Past the reach the envelope is zero, so eighteen screenshots of a
    /// landing every 1.5 seconds caught nothing. Everything measured green:
    /// the cells were in the right places, the lattice was the right width,
    /// and no frame was dropped.
    ///
    /// So this walks a whole landing and asks what a person would have SEEN:
    /// each of the four cells next to the block has to light up at an alpha
    /// that is actually a colour on the page.
    ///
    /// **Proven able to fail**: it goes red if the envelope decays from the
    /// ring's centre rather than from the block's edge and `peak` is left
    /// where it is for a 1x1 (0.104 against the 0.05 floor is fine, but drop
    /// `peak` to 0.06 or shorten `reach` to 1.0 and it is not), and it goes
    /// red outright for any front that never enters the reach.
    @Test("Every ring around a landing is lit, at an alpha somebody can see")
    func theRingIsVisibleWhileItTravels() {
        let pitch = cell + spacing
        let rect = CGRect(x: 0, y: 0, width: GridConstants.gridWidth(cellSize: cell), height: 913)
        // Below this a tint is not a colour on a warm white page, it is a
        // rounding error. Measured from the shipped numbers, which put the
        // first ring of a 1x1 at 0.11.
        let visible = 0.05

        for (columnSpan, rowSpan) in [(1, 1), (2, 1), (2, 2)] {
            let r = ripple(column: 1, row: 2, columnSpan: columnSpan, rowSpan: rowSpan)
            let peak = TowerLattice.peak(for: r.span)
            // The four cells that share an edge with the block.
            var wanted: Set<String> = []
            func key(column: Int, row: Int) -> String {
                let x = CGFloat(column) * pitch
                let top = rect.maxY - cell - CGFloat(row) * pitch
                return "\(Int(x.rounded()))/\(Int(top.rounded()))"
            }
            wanted.insert(key(column: 0, row: 2))
            wanted.insert(key(column: 1 + columnSpan, row: 2))
            wanted.insert(key(column: 1, row: 2 + rowSpan))
            wanted.insert(key(column: 1, row: 1))

            var seen: Set<String> = []
            for step in 0...400 {
                let phase = Double(step) / 400
                let front = TowerLattice.front(atPhase: phase, span: r.span)
                let alpha = peak * TowerLattice.envelope(front: front, ripple: r)
                guard alpha >= visible else { continue }
                for lit in cells(r, front: front, band: 0...TowerLattice.frontBand, in: rect) {
                    seen.insert("\(Int(lit.minX.rounded()))/\(Int(lit.minY.rounded()))")
                }
            }
            #expect(wanted.isSubset(of: seen),
                    "a \(columnSpan)x\(rowSpan) never lit \(wanted.subtracting(seen)) at \(visible) alpha or better")
        }
    }

    /// The envelope is full where the block's edge is and spent at the reach.
    /// It used to decay from the ring's CENTRE, which is under the block, so
    /// `peak` was never what a cell actually got.
    @Test("A landing is at full strength beside the block and spent at its reach")
    func theEnvelopeIsSpentOverTheVisibleCells() {
        for (columnSpan, rowSpan) in [(1, 1), (2, 1), (2, 2)] {
            let r = ripple(column: 0, row: 0, columnSpan: columnSpan, rowSpan: rowSpan)
            let edge = CGFloat(max(columnSpan, rowSpan)) / 2
            let reach = TowerLattice.reach(for: r.span)
            #expect(TowerLattice.envelope(front: edge, ripple: r) == 1.0)
            #expect(TowerLattice.envelope(front: reach, ripple: r) == 0.0)
            // And monotone, so it never brightens on its way out.
            var last = 1.0
            for step in 0...100 {
                let value = TowerLattice.envelope(front: CGFloat(step) / 100 * reach, ripple: r)
                #expect(value <= last + 0.0001, "the ring brightened at \(value) after \(last)")
                last = value
            }
        }
    }

    // MARK: - A photograph's colour

    /// **A photograph's colour has to come out somewhere the lattice can show
    /// it at 15 to 26 percent alpha.** A dark or muddy average would read as
    /// dirt on a warm white page rather than as a reaction.
    ///
    /// **Proven able to fail**: widen either band and a near-black photograph
    /// comes back at 0.09 brightness.
    @Test("A photograph's colour is pulled into the band")
    func aPhotographsColourIsCalmed() {
        let awkward: [(name: String, rgb: (Double, Double, Double))] = [
            ("a night shot", (0.04, 0.05, 0.09)),
            ("a grey wall", (0.55, 0.55, 0.56)),
            ("a neon sign", (1.0, 0.0, 0.62)),
            ("a blown sky", (0.97, 0.98, 1.0))
        ]
        for shot in awkward {
            let measured = LatticeTint.hsb(r: shot.rgb.0, g: shot.rgb.1, b: shot.rgb.2)
            let calmed = LatticeTint.calmed(measured)
            #expect(LatticeTint.saturation.contains(calmed.s),
                    "\(shot.name) came out at \(calmed.s) saturation")
            #expect(LatticeTint.brightness.contains(calmed.b),
                    "\(shot.name) came out at \(calmed.b) brightness")
            // The hue is the photograph's and is never invented.
            #expect(abs(calmed.h - measured.h) < 0.0001)
        }
    }

    /// The average is weighted toward whatever the picture is coloured by, so
    /// a photograph that is mostly neutral with one strong colour in it does
    /// not come back grey.
    ///
    /// **Proven able to fail**: an unweighted mean of this image is at 0.30
    /// saturation before clamping and its hue drifts toward the grey.
    @Test("A photograph's colour follows the colour in it, not the grey")
    func theAverageFollowsTheColour() {
        let side = 64
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for row in 0..<side {
            for column in 0..<side {
                let i = (row * side + column) * 4
                // Three quarters dead neutral grey, one quarter strong blue.
                let blue = column >= side * 3 / 4
                bytes[i] = blue ? 20 : 128
                bytes[i + 1] = blue ? 70 : 128
                bytes[i + 2] = blue ? 220 : 128
                bytes[i + 3] = 255
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false,
                            intent: .defaultIntent)!
        let mean = LatticeTint.mean(of: image)
        #expect(mean != nil)
        guard let mean else { return }
        // Blue sits at 0.625 round the wheel; a neutral grey has no hue at
        // all and contributes at the weight floor.
        let apart = abs(mean.h - 0.625)
        #expect(min(apart, 1 - apart) < 0.15, "the average came back at hue \(mean.h)")
        // **The number that separates weighted from unweighted.** A flat mean
        // of this picture is 0.227 saturation; the weighted one is about 0.63.
        #expect(mean.s > 0.30, "the average came back at \(mean.s) saturation, which is grey")
    }
}
