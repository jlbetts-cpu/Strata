import SwiftUI
#if DEBUG
import os
/// `-strataLatticeLog`: one line per landing, for checking WHICH colour the
/// surface answered a photographed win in. Off unless the flag is passed, and
/// the message is an autoclosure so a run without it builds no strings.
/// Never on the per-frame draw path: a probe that formatted a string for
/// every band of every frame was, itself, work on the frame the block lands
/// on.
enum LatticeProbe {
    static let isOn = ProcessInfo.processInfo.arguments.contains("-strataLatticeLog")
    static let log = Logger(subsystem: "Strata", category: "lattice")
    static func note(_ message: @autoclosure () -> String) {
        guard isOn else { return }
        // Evaluated into a local first: the log's own interpolation escapes
        // what it is handed, and a non-escaping autoclosure cannot be.
        let text = message()
        log.notice("[PERF-LAT] \(text, privacy: .public)")
    }
}
#endif

/// **The surface the tower is built on.**
///
/// The owner, 2026-09-23: "the blocks right now, they don't feel like they
/// fit when there is a bunch of images, like they just don't fit well inside
/// of there when they are mixed, it looks a bit odd. I think the easy fix
/// would be to add structure to the background, like a grid of some sort that
/// helps structure the screen. But I don't want it to look cheap, it has to
/// be like if Apple designed it: minimal, clean. And really help the user
/// understand."
///
/// **What the problem actually is.** A tower of flat colours is a composition
/// somebody chose; the same tower with photographs in half the slots is two
/// kinds of object on one page, and the photographs bring their own colour,
/// their own contrast and their own edges. Nothing on the page says the two
/// belong to the same system, so the mixed tower reads as a collage.
///
/// **So this is not wallpaper, it is the grid the blocks land in.** Same cell
/// size, same 4pt gutter, same corner radius, anchored to the same bottom row.
/// A block does not sit ON the pattern, it FILLS one of these cells, and the
/// empty ones carry on above it. That is the part that teaches: you can see
/// the slots, so you can see that a small win takes one and a big one takes
/// four, and a photograph is just a slot with a picture in it.
///
/// **Why cells and not lines.** A ruled lattice of hairlines is graph paper:
/// it is a second geometry laid over the first, its lines land in the
/// gutters, and at this contrast hairlines alias into a grey haze on a
/// scrolling view. Filled cells are the app's own shape at the app's own
/// radius, they have no sub-pixel edge to shimmer, and the 4pt gutter stays
/// the gutter rather than becoming a drawn line.
///
/// **It fades upward** so the screen is grounded rather than caged. Strongest
/// under the tower, gone well before the top of the viewport, which is also
/// what keeps it from reading as an empty state waiting to be filled in.
struct TowerLattice: View {
    /// The tower's cell, which is `colW` at the call site: the same number
    /// every block is measured with.
    var cellSize: CGFloat
    /// How tall the tower's own grid is, so the lattice knows where the
    /// content ends and its own overhang begins.
    var contentHeight: CGFloat
    var spacing: CGFloat = GridConstants.spacing
    var columns: Int = GridConstants.columnCount

    /// **How far above the tower the lattice carries on, in rows.**
    ///
    /// It was a whole viewport, and photographed that was the failure he
    /// warned about: a checkerboard from the tab bar to the status bar, at
    /// one strength, with the fade finishing off screen above. The lattice
    /// is a surface the tower stands on, not a backdrop the app lives in, so
    /// it reaches a few rows past the top block and is gone.
    static let rowsAbove = 3

    /// **How much ink an empty cell gets, as a share of `quietFill`.**
    ///
    /// `AppColors.quietFill` is the app's "empty cell" token at 6% ink, which
    /// is right for ONE well on a page and too strong for a field of them:
    /// at 6% the lattice reads as a checkerboard and competes with the
    /// blocks. Rendered and looked at rather than reasoned about.
    /// **Photographed at 0.55 and it was a checkerboard**, which is exactly
    /// the cheap he asked this not to be. The cells have to be findable and
    /// then forgotten: enough that the tower reads as built into something,
    /// not enough to count them without looking for them.
    static let strength: Double = 0.34

    /// **What the surface is worth at the peak of a landing**, over the
    /// resting cells, in the block's own colour.
    ///
    /// The owner, 2026-09-23: "it's not actually using the lattice, it's like
    /// a separate ripple that shouldn't be there... they should react to a
    /// block dropping, ripple with the colour or something, depending on how
    /// big the block is."
    ///
    /// The first version was a band that swept the whole lattice whenever you
    /// arrived on the screen, and he is right that it reads as an overlay
    /// rather than as the surface: a soft wash crossing everything, in grey,
    /// for no reason anybody asked for. Nothing animates on arrival now.
    /// **A landing is the only thing that moves the lattice**, it moves it
    /// from where the block actually hit, and it is the block's colour.
    static func peak(for span: Int) -> Double {
        switch span {
        case 4: return 0.26     // a 2x2
        case 2: return 0.20     // a 2x1
        default: return 0.15    // a 1x1
        }
    }

    /// How far the ring travels, in cells, and how long it takes.
    ///
    /// **Speed is the motto**, so even the heaviest block is done in two
    /// thirds of a second: long enough to read as the surface answering,
    /// short enough that it is over before you have looked for it.
    static func reach(for span: Int) -> CGFloat {
        switch span {
        case 4: return 5.0
        case 2: return 3.6
        default: return 2.6
        }
    }

    static func duration(for span: Int) -> Double {
        switch span {
        case 4: return 0.66
        case 2: return 0.52
        default: return 0.42
        }
    }

    /// The landing the surface is answering, if it is answering one.
    var ripple: LatticeRipple? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pitch: CGFloat { cellSize + spacing }
    private var overhang: CGFloat { CGFloat(Self.rowsAbove) * pitch }
    private var height: CGFloat { max(contentHeight, 1) + overhang }

    var body: some View {
        resting
            .overlay { landing }
            .mask {
                // **The fade is spent on the overhang, not on the whole
                // height.** As a share of the lattice it finished above the
                // top of the screen and every visible cell came out at full
                // strength. In points it always lands where the tower ends:
                // clear at the top, full by the time it reaches the block.
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: min(overhang / height, 1)),
                    .init(color: .black, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The lattice as it sits: every cell at `strength`.
    private var shape: TowerLatticeShape {
        TowerLatticeShape(cellSize: cellSize, spacing: spacing, columns: columns)
    }

    private var resting: some View {
        shape.fill(AppColors.quietFill.opacity(Self.strength))
            .frame(height: height)
    }

    /// **The landing, drawn as the cells it reaches.**
    ///
    /// A ring travels out from the cells the block just filled, and every
    /// cell it passes takes the block's colour for a moment. The owner:
    /// "it's not actually using the lattice, it's like a separate ripple
    /// that shouldn't be there... they should react to a block dropping."
    ///
    /// **One animated number drives all of it**, through a keyframe track:
    /// how far through the landing we are, 0 to 1. The cells the ring is
    /// passing are the only ones drawn, and the colour fades as it travels,
    /// so the envelope comes out of the same number rather than out of a
    /// second animation that could drift against it.
    ///
    /// **No `TimelineView` and no `Canvas`, and that is a measurement rather
    /// than a preference.** Both of those were built first, and mounting a
    /// paused timeline that woke for each landing cost a 50ms frame gap
    /// every time: sixteen of them in 38 seconds with the lab dropping a
    /// block every 1.5s, against zero in the same run with no landings. The
    /// gap landed on exactly the frame the block hits, which is the one
    /// moment the screen has to be smooth.
    private var landing: some View {
        // **Mounted always, played by a change of trigger.**
        //
        // It was wrapped in `if let ripple`, which looks tidier and cannot
        // work: every landing is a different value, so the whole subtree was
        // re-created and a keyframe animator that has just appeared has no
        // trigger CHANGE to play. One mounted view, and the trigger is the
        // moment of impact.
        Color.clear
            .frame(height: height)
            .keyframeAnimator(initialValue: 0.0, trigger: ripple?.started ?? .distantPast) { view, phase in
                view.overlay { rings(phase: phase) }
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    // **One ease-out keyframe, and NOT a spring.**
                    //
                    // A `SpringKeyframe` inherits the velocity of the
                    // keyframe before it, and this track used to open with a
                    // 1ms hop from a resting sentinel of -2 up to 0. Two
                    // cells in a millisecond is 2000 cells a second, the
                    // spring launched at that, and the ring left the screen
                    // instead of crossing it. Measured with the lab running
                    // and every frame logged: of 3023 frames of ripple,
                    // 459 sat on the sentinel, exactly ONE had the front
                    // inside the reach, and the rest were 4.1 to 78.6 cells
                    // out against a reach of at most 5. Past the reach the
                    // envelope is zero, so every landing drew nothing. That
                    // is the whole of the "eighteen screenshots caught no
                    // ripple" bug. A linear keyframe on an ease-out curve
                    // has no velocity to inherit and cannot overshoot.
                    LinearKeyframe(1.0,
                                   duration: Self.duration(for: ripple?.span ?? 1),
                                   timingCurve: .easeOut)
                }
            }
            .allowsHitTesting(false)
    }

    /// The two rings: the cells the front is on, and the ones just behind it.
    ///
    /// Two bands rather than a gradient, because a cell is either reacting or
    /// it is not — the quantising is what makes this read as the surface
    /// rather than as a glow laid over it.
    @ViewBuilder
    private func rings(phase: Double) -> some View {
        // **`phase` runs 0 to 1, and it is deliberately not the front in
        // cells.** Both ends of it draw nothing, which is what lets one
        // mounted animator rest between landings: 0 before the first one and
        // 1 after each. A track that rested on "the reach" would rest on a
        // different number for every block size, so a landing of a different
        // size to the one before it would draw a stale ring for the frame
        // before its own track started.
        if let ripple, !reduceMotion, phase > 0, phase < 1 {
            ringLayers(ripple, phase: phase)
        }
    }

    /// Where the ring's front is, in cells, at a given point in the landing.
    ///
    /// The one place `phase` becomes a distance, so a test can walk a whole
    /// landing and ask what was visible during it rather than trusting the
    /// animation to have taken the values it was asked for. It did not: see
    /// the keyframe track above.
    static func front(atPhase phase: Double, span: Int) -> CGFloat {
        CGFloat(phase) * reach(for: span)
    }

    @ViewBuilder
    private func ringLayers(_ ripple: LatticeRipple, phase: Double) -> some View {
        let front = Self.front(atPhase: phase, span: ripple.span)
        let peak = Self.peak(for: ripple.span)
        let envelope = Self.envelope(front: front, ripple: ripple)
        RippleCells(front: front, band: 0...Self.frontBand, ripple: ripple,
                    cellSize: cellSize, spacing: spacing, columns: columns)
            .fill(ripple.colour.opacity(peak * envelope))
        RippleCells(front: front, band: Self.frontBand...Self.backBand, ripple: ripple,
                    cellSize: cellSize, spacing: spacing, columns: columns)
            .fill(ripple.colour.opacity(peak * envelope * 0.45))
    }

    /// How thick the ring is, in cells: the band at full strength, and the
    /// one trailing it at under half. A cell inside the first band is lit for
    /// `frontBand` cells of travel, which at these reaches is five or six
    /// frames — long enough to read as that cell answering rather than as a
    /// flicker passing over it.
    static let frontBand: CGFloat = 0.70
    static let backBand: CGFloat = 1.70

    /// **The energy is spent over the cells somebody can actually SEE.**
    ///
    /// The decay used to run from the ring's centre, which is underneath the
    /// block: the nearest cell the block is not already covering is a whole
    /// cell out from a 1x1's centre, so the ring reached the first visible
    /// cell with a third of `peak` already gone and `peak` never meant what
    /// its own doc comment says. It runs from the block's own edge now, so a
    /// cell beside the block gets the full number and the last cell within
    /// reach gets none.
    static func envelope(front: CGFloat, ripple: LatticeRipple) -> Double {
        let reach = reach(for: ripple.span)
        let edge = CGFloat(max(ripple.columnSpan, ripple.rowSpan)) / 2
        guard front > 0 else { return 0 }
        let travelled = max(0, front - edge)
        return max(0, min(1, 1 - Double(travelled / max(reach - edge, 0.01))))
    }

}

/// **A landing, as the lattice needs to know it.**
///
/// Where the block came to rest, how big it is, and what colour it is. The
/// surface needs nothing else, and taking only this keeps the lattice out of
/// the tower's model: it cannot accidentally start depending on a habit, a
/// log or a view model.
struct LatticeRipple: Equatable {
    var column: Int
    var row: Int
    var columnSpan: Int
    var rowSpan: Int
    var colour: Color
    /// When it hit. The canvas reads the clock rather than a counter, so a
    /// dropped frame does not slow the ring down, it just misses it.
    var started: Date = Date()

    /// How many cells the block covers, which is what the ripple is scaled
    /// by: a Quick taps the surface, a Deep hits it.
    var span: Int { columnSpan * rowSpan }
}


/// Every cell of the tower's grid, from the bottom row upward.
///
/// **Bottom anchored, because the tower is.** A block's frame comes from
/// `GridConstants.blockFrame(column:row:...)` and is then flipped so row 0
/// sits on the ground; the lattice is built the same way round, from
/// `rect.maxY` up, so the ground row of cells is exactly the ground row of
/// blocks whatever the height happens to be. Measuring down from the top
/// would put the two half a gutter out of step at any height that is not a
/// whole number of rows.
struct TowerLatticeShape: Shape {
    var cellSize: CGFloat
    var spacing: CGFloat
    var columns: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = GridConstants.blockCornerRadius(forCell: cellSize)
        for cell in cellRects(in: rect) {
            path.addRoundedRect(in: cell,
                                cornerSize: CGSize(width: radius, height: radius),
                                style: .continuous)
        }
        return path
    }

    /// **Where every cell is, as numbers rather than as a drawn path.**
    ///
    /// Separate from `path(in:)` so a test can hold it against
    /// `GridConstants.blockFrame`, which is the only thing that makes this
    /// safe: a lattice a few points out of step with the blocks is worse
    /// than no lattice, and it is the kind of wrong nobody notices in a
    /// screenshot until the day a cell size changes. The ripple walks the
    /// same list, so the cells that light up are the cells that are drawn.
    func cellRects(in rect: CGRect) -> [CGRect] {
        guard cellSize > 0, columns > 0 else { return [] }
        let pitch = cellSize + spacing
        var rects: [CGRect] = []
        var top = rect.maxY - cellSize
        // One row past the top edge, so a cell that is only half on screen is
        // still drawn rather than stopping in a straight line of its own.
        while top > rect.minY - pitch {
            for column in 0..<columns {
                let x = rect.minX + CGFloat(column) * pitch
                rects.append(CGRect(x: x, y: top, width: cellSize, height: cellSize))
            }
            top -= pitch
        }
        return rects
    }
}


/// **The cells a ring is passing through, right now.**
///
/// A `Shape` rather than a canvas so SwiftUI's own animation drives it: the
/// keyframe track hands `front` a new value each frame and this draws the
/// cells at that distance from the landing. Only the ring's cells are built,
/// so the work per frame is a dozen rounded rectangles rather than the whole
/// lattice.
struct RippleCells: Shape {
    /// How far out the ring has travelled, in cells.
    var front: CGFloat
    /// Which slice behind the front this layer draws, in cells.
    var band: ClosedRange<CGFloat>
    var ripple: LatticeRipple
    var cellSize: CGFloat
    var spacing: CGFloat
    var columns: Int

    private var pitch: CGFloat { cellSize + spacing }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = GridConstants.blockCornerRadius(forCell: cellSize)
        for cell in litCells(in: rect) {
            path.addRoundedRect(in: cell,
                                cornerSize: CGSize(width: radius, height: radius),
                                style: .continuous)
        }
        return path
    }

    /// **Which cells the ring is on right now, as numbers rather than as a
    /// drawn path.**
    ///
    /// Separate from `path(in:)` for the same reason
    /// `TowerLatticeShape.cellRects` is: a test can hold it against
    /// `GridConstants.blockFrame` and against the landing's own column and
    /// row. A ring a row out of step with the block that caused it is the
    /// kind of wrong nobody sees in a screenshot, and the ring being invisible
    /// for its whole life was not caught by looking either.
    func litCells(in rect: CGRect) -> [CGRect] {
        guard cellSize > 0, columns > 0, front > 0 else { return [] }
        var cells: [CGRect] = []
        let origin = origin(in: rect)
        // A row whose vertical distance alone already exceeds the front
        // cannot hold a cell the ring has reached, so it is skipped before
        // its cells are ever considered.
        let outer = front + 1
        var row = 0
        var top = rect.maxY - cellSize
        while top > rect.minY - pitch {
            let dy = (top + cellSize / 2 - origin.y) / pitch
            if abs(dy) <= outer {
                for column in 0..<columns {
                    // **A cell the block is standing in is not an empty cell
                    // any more, so it does not react.** Photographed without
                    // this the ring read as a filled patch rather than as the
                    // surface answering around the landing: the four cells at
                    // the centre light first and brightest, and the ring only
                    // becomes a ring once it has left them. On the tower a
                    // block covers them and nobody sees it, which is exactly
                    // the kind of thing that looks fine until the day
                    // something is drawn where a block is not.
                    if column >= ripple.column, column < ripple.column + ripple.columnSpan,
                       row >= ripple.row, row < ripple.row + ripple.rowSpan { continue }
                    let x = rect.minX + CGFloat(column) * pitch
                    let dx = (x + cellSize / 2 - origin.x) / pitch
                    let behind = front - sqrt(dx * dx + dy * dy)
                    guard band.contains(behind) else { continue }
                    cells.append(CGRect(x: x, y: top, width: cellSize, height: cellSize))
                }
            }
            top -= pitch
            row += 1
        }
        return cells
    }

    /// **Bottom anchored, like everything else here.** The tower's row 0 is
    /// on the ground and the lattice's bottom row is the same row, so a
    /// block's centre is measured up from `maxY` rather than down from the
    /// top: the lattice is taller than the grid by its overhang, and
    /// measuring from the top would put the ring a few rows out.
    func origin(in rect: CGRect) -> CGPoint {
        let x = rect.minX
            + CGFloat(ripple.column) * pitch
            + (CGFloat(ripple.columnSpan) * cellSize
               + CGFloat(ripple.columnSpan - 1) * spacing) / 2
        let y = rect.maxY
            - CGFloat(ripple.row) * pitch
            - (CGFloat(ripple.rowSpan) * cellSize
               + CGFloat(ripple.rowSpan - 1) * spacing) / 2
        return CGPoint(x: x, y: y)
    }
}


/// **The colour a landing ripples in when the block is a photograph.**
///
/// The owner, 2026-09-23: "make sure the ripple ripples like the color of the
/// block or the photo of the block, like that would look sick."
///
/// A typed win has one colour and the lattice takes it. A win with a
/// photograph on it has the photograph, and the surface should answer with
/// what actually landed rather than with the category the win happens to be
/// filed under.
///
/// **Nothing here may cost anything on the frame the block lands on.** So the
/// category colour goes up immediately and this runs behind it: the caller
/// gets the photograph's colour in a callback and swaps it in underneath the
/// ring that is already running. A landing whose photograph is not in memory
/// keeps the category colour and never waits for one.
///
/// **It reads only what the app is ALREADY holding.** `cachedThumbnail` is a
/// cache peek: no disk, no decode, no scheduling, and no derivative baked on
/// this account. On the tower the block being landed on is drawing its own
/// photograph, so the thumbnail is usually there; when it is not, the
/// category colour is the answer and that is a correct answer, not a
/// degraded one.
@MainActor
enum LatticeTint {

    /// **The band a photograph's colour is pulled into.**
    ///
    /// `FolderTint` on `apollo-rename` is the approved prior art and its test
    /// pins saturation to 0.06...0.34 and brightness to 0.55...0.95. The
    /// brightness half carries over almost unchanged and for the same reason:
    /// a dark photograph averages to something near black, and near black on
    /// a warm white page is a smudge rather than a colour. The top end comes
    /// in a little, to 0.92, because a ring sits over white and has nothing
    /// to be bright against.
    ///
    /// **The saturation band does NOT carry over, and that is deliberate.**
    /// A folder's colour is drawn at full alpha as the folder's own surface.
    /// A ring is the same colour at 15 to 26 percent over near white, which
    /// divides its chroma by about four, so a folder's 0.34 ceiling would put
    /// a photographed win's ring at a quarter of the chroma of the typed win's
    /// ring beside it — the "switched off" failure `FolderTint` records about
    /// its own Ink entry, in a place where it matters more. The floor of 0.35
    /// is what stops a muddy brown or grey average reading as dirt on the
    /// page; the ceiling of 0.75 is under every category colour in
    /// `CategoryColors`, so a photograph can never ripple louder than a typed
    /// win.
    nonisolated static let saturation: ClosedRange<Double> = 0.35...0.75
    nonisolated static let brightness: ClosedRange<Double> = 0.55...0.92

    /// Derived colours, by the block's id. Bounded, because a long session
    /// scrolling a year of wins would otherwise grow it without limit.
    private static var derived: [UUID: Color] = [:]
    private static var inFlight: Set<UUID> = []
    nonisolated static let cacheLimit = 240

    /// The photograph's colour if it has already been worked out. Free, and
    /// the only thing a landing is allowed to ask for synchronously.
    static func cached(for id: UUID) -> Color? { derived[id] }

    /// Works out the photograph's colour off the main actor and hands it back.
    /// Called back at most once per block, on the main actor, and never on
    /// the landing frame.
    static func tint(for id: UUID, fileName: String,
                     then: @escaping @MainActor (Color) -> Void) {
        if let hit = derived[id] { then(hit); return }
        guard !inFlight.contains(id) else { return }
        inFlight.insert(id)
        // Read on the main actor, where `ThumbnailStore` lives, and hand the
        // plain numbers to the background.
        let widths = ThumbnailStore.widthBuckets
        Task.detached(priority: .userInitiated) {
            let found = colour(ofPhotograph: fileName, widths: widths)
            await MainActor.run {
                inFlight.remove(id)
                guard let found else { return }
                let colour = Color(hue: found.h, saturation: found.s, brightness: found.b)
                if derived.count >= cacheLimit { derived.removeAll(keepingCapacity: true) }
                derived[id] = colour
                #if DEBUG
                LatticeProbe.note(String(format: "tint %@ h=%.3f s=%.3f b=%.3f",
                                         fileName, found.h, found.s, found.b))
                #endif
                then(colour)
            }
        }
    }

    /// For tests, and for a store reset: nothing here survives a photograph
    /// being replaced otherwise.
    static func forget() {
        derived.removeAll()
        inFlight.removeAll()
    }

    /// The smallest thumbnail of this photograph that is already in memory,
    /// averaged and calmed. `nil` when the app is not holding one, which is
    /// the caller's signal to stay on the category colour.
    nonisolated static func colour(ofPhotograph fileName: String,
                                   widths: [Int]) -> (h: Double, s: Double, b: Double)? {
        for width in widths {
            guard let image = ImageManager.shared.cachedThumbnail(fileName: fileName,
                                                                  maxWidth: CGFloat(width)),
                  let cg = image.cgImage,
                  let mean = mean(of: cg)
            else { continue }
            return calmed(mean)
        }
        return nil
    }

    /// **An 8x8 average, weighted toward the colour in the picture.**
    ///
    /// A flat mean of a photograph is very often grey: a red jumper and a
    /// green field average to mud, and mud at 20 percent over a warm white
    /// page reads as a stain. Weighting each of the 64 cells by its own
    /// saturation pulls the answer toward whatever the picture is actually
    /// coloured by, and the 0.15 floor on the weight keeps a photograph that
    /// really is neutral from being decided by its noisiest pixel. Hue is
    /// averaged as a vector, because hue wraps and a mean of 355 and 5 is
    /// not 180.
    nonisolated static func mean(of image: CGImage) -> (h: Double, s: Double, b: Double)? {
        let side = 8
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drew: Bool = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: side, height: side,
                                          bitsPerComponent: 8, bytesPerRow: side * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drew else { return nil }
        var hx = 0.0, hy = 0.0, sSum = 0.0, bSum = 0.0, weight = 0.0
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let cell = hsb(r: Double(bytes[index]) / 255,
                           g: Double(bytes[index + 1]) / 255,
                           b: Double(bytes[index + 2]) / 255)
            let w = 0.15 + cell.s
            hx += cos(cell.h * 2 * .pi) * w
            hy += sin(cell.h * 2 * .pi) * w
            sSum += cell.s * w
            bSum += cell.b * w
            weight += w
        }
        guard weight > 0 else { return nil }
        var hue = atan2(hy, hx) / (2 * .pi)
        if hue < 0 { hue += 1 }
        return (hue, sSum / weight, bSum / weight)
    }

    /// Into the band. See `saturation` and `brightness`.
    nonisolated static func calmed(_ colour: (h: Double, s: Double, b: Double))
    -> (h: Double, s: Double, b: Double) {
        (colour.h,
         min(max(colour.s, saturation.lowerBound), saturation.upperBound),
         min(max(colour.b, brightness.lowerBound), brightness.upperBound))
    }

    nonisolated static func hsb(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let high = max(r, g, b), low = min(r, g, b)
        let span = high - low
        guard span > 0, high > 0 else { return (0, 0, high) }
        var hue: Double
        switch high {
        case r: hue = (g - b) / span
        case g: hue = 2 + (b - r) / span
        default: hue = 4 + (r - g) / span
        }
        hue /= 6
        if hue < 0 { hue += 1 }
        return (hue, span / high, high)
    }
}
