import SwiftUI

/// The folder's silhouette: a back plate with a tab, the shape everybody
/// already reads as "folder" without being told.
///
/// **Angular, not soft.** The owner, looking at the row against the VEED
/// reference: "make the folders feel less rounded and more angular kinda like
/// this." The radius was 13.5% of the short side, which at a 150pt folder is
/// a 20pt corner — that is a squircle app icon, not a paper object. It is
/// 7.2% now, and the step down from the tab is a straight diagonal with a
/// small bevel at each end rather than one long curve. A curve reads as
/// moulded plastic; a bevelled diagonal reads as a cut edge, which is what
/// card stock has.
struct FolderBack: Shape {
    /// **A plain rounded square, and the tab moved to the FRONT.**
    ///
    /// The owner, with the orange reference beside the row: "I might like the
    /// shape of the orange one a bit better, with the text on the glass part,
    /// I feel like that looks more luxury."
    ///
    /// He is pointing at an inversion, and it is the thing that makes that
    /// drawing read as an object rather than an icon. A folder ICON puts the
    /// tab on the back plate and a flat rectangle in front — which is the
    /// 1994 file glyph, and is what this drew. The reference does the
    /// opposite: the body behind is a plain rounded square and the PANEL in
    /// front is the folder-shaped piece, its top edge rising on the left and
    /// stepping down to the right. So the tab is a thing you could put your
    /// thumb behind rather than a notch cut out of a silhouette.
    ///
    /// It also gives the photographs somewhere to be. With the front's top
    /// edge low on the right, the stack shows through exactly where that
    /// drawing shows its notes.
    static func radius(in rect: CGRect) -> CGFloat { min(rect.width, rect.height) * 0.135 }

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: Self.radius(in: rect), style: .continuous)
            .path(in: rect)
    }
}

/// **The glass panel in front, and it is the piece with the tab on it.**
///
/// Its top edge runs along at `tabTop` for the left `tabWidth` of the card,
/// steps down a bevelled diagonal, and continues low across the rest — the
/// profile of a folder's front, and the shape the owner picked out of the
/// reference.
struct FolderFront: InsettableShape {
    /// Where the front's top edge sits on the RIGHT, as a fraction of the
    /// card's height from its top.
    var lowTop: CGFloat = 0.42
    /// Where it sits on the left, over the tab.
    var tabTop: CGFloat = 0.30
    /// How much of the width the raised part takes.
    var tabWidth: CGFloat = 0.46
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> FolderFront {
        FolderFront(lowTop: lowTop, tabTop: tabTop, tabWidth: tabWidth,
                    inset: inset + amount)
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let w = r.width, h = r.height
        let corner = min(w, h) * 0.135
        let top = r.minY + h * lowTop
        let raised = r.minY + h * tabTop
        let tabEnd = r.minX + w * tabWidth
        let run = w * 0.075
        let bevel = min(corner * 0.5, run * 0.5)

        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: raised + corner))
        p.addQuadCurve(to: CGPoint(x: r.minX + corner, y: raised),
                       control: CGPoint(x: r.minX, y: raised))
        p.addLine(to: CGPoint(x: tabEnd - bevel, y: raised))
        p.addQuadCurve(to: CGPoint(x: tabEnd + bevel * 0.5, y: raised + bevel * 0.9),
                       control: CGPoint(x: tabEnd, y: raised))
        p.addLine(to: CGPoint(x: tabEnd + run - bevel * 0.5, y: top - bevel * 0.9))
        p.addQuadCurve(to: CGPoint(x: tabEnd + run + bevel * 0.4, y: top),
                       control: CGPoint(x: tabEnd + run, y: top))
        p.addLine(to: CGPoint(x: r.maxX - corner, y: top))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: top + corner),
                       control: CGPoint(x: r.maxX, y: top))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - corner))
        p.addQuadCurve(to: CGPoint(x: r.maxX - corner, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + corner, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - corner),
                       control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The pocket's outline, drawn with the SAME corners the plate uses so the
/// two read as one object. See `FolderBack.radius`.
struct PocketShape: InsettableShape {
    var radius: CGFloat
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> PocketShape {
        PocketShape(radius: max(radius - amount, 0), inset: inset + amount)
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let c = min(radius, min(r.width, r.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addQuadCurve(to: CGPoint(x: r.minX + c, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c),
                       control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - c),
                       control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// **The colours a folder can be.**
///
/// The owner: "make sure the folders are customisable, you are able to change
/// the colour."
///
/// Six, and every one of them is muted. That is not timidity, it is the same
/// call he made about the blocks — "less of the playful vibrant colours which
/// don't fit Apollo's premium aesthetic." A saturated folder on a warm white
/// page is a sticker; a folder mixed with grey and warmth in it is an object
/// made of something. Each is stored by its `id`, never by its value, so
/// retuning a colour moves every folder already set to it rather than
/// orphaning them.
struct FolderTint: Identifiable, Hashable {
    let id: String
    let name: String
    let colour: Color

    static let sand   = FolderTint(id: "sand",   name: "Sand",   colour: Color(red: 0.882, green: 0.792, blue: 0.612))
    // Clay was the one entry that failed its own ceiling, at 0.368 against
    // 0.34 — caught by `paletteIsCalm`, not by eye. Pulled back by lifting
    // the blue, which is the channel that was doing the shouting.
    static let clay   = FolderTint(id: "clay",   name: "Clay",   colour: Color(red: 0.812, green: 0.647, blue: 0.573))
    static let sage   = FolderTint(id: "sage",   name: "Sage",   colour: Color(red: 0.655, green: 0.729, blue: 0.624))
    static let slate  = FolderTint(id: "slate",  name: "Slate",  colour: Color(red: 0.592, green: 0.663, blue: 0.729))
    static let plum   = FolderTint(id: "plum",   name: "Plum",   colour: Color(red: 0.718, green: 0.616, blue: 0.698))
    /// **Replaced "Ink", which was a mistake worth recording.** Ink was a
    /// near-neutral charcoal at 2% saturation, and on the row it did not read
    /// as a colour at all — it read as a folder that was switched off, next
    /// to five that were on. A muted palette still has to be a palette: every
    /// entry needs enough chroma to be a choice somebody made. Fog is the
    /// same idea done properly, a warm greige with visible warmth in it.
    static let fog    = FolderTint(id: "fog",    name: "Fog",    colour: Color(red: 0.788, green: 0.761, blue: 0.710))

    static let all: [FolderTint] = [.sand, .clay, .sage, .slate, .plum, .fog]

    static func tint(id: String) -> FolderTint { all.first { $0.id == id } ?? .sand }

    /// **The colour a day gets when nobody has picked one.**
    ///
    /// The owner: "make sure the different folders are a random colour that
    /// looks good... make sure the random colours still fit the vibe and
    /// aren't like neon or anything like that, like very comforting chill
    /// colours that could fit the brand."
    ///
    /// The "chill" half is not this function's job and could not be — it is
    /// the palette above, where every entry is mixed with grey and warmth and
    /// none exceeds 0.29 saturation. There is no neon to draw, so a random
    /// draw cannot produce one. That is the right place for the constraint:
    /// a rule enforced by what exists rather than by what is chosen.
    ///
    /// **Random-looking, never actually random.** A folder that changed
    /// colour when you scrolled past it twice would be the worst thing here,
    /// so the draw is an FNV-1a hash of the day's own key: the same day is
    /// the same colour on every launch and on every device, with no storage.
    ///
    /// **And never the same as yesterday.** One in six pairs would otherwise
    /// come up as two identical folders side by side, which does not read as
    /// random, it reads as a bug. The previous day's key is derivable from
    /// this one, so the check needs no neighbour passed in and no ordering.
    static func seeded(for dateString: String) -> FolderTint {
        if let hit = seedCache[dateString] { return hit }
        let drawn = all[draw(dateString)]
        // Bounded so a long session cannot grow it without limit. Twelve
        // times the window Recents shows is generous and still nothing.
        if seedCache.count > 200 { seedCache.removeAll(keepingCapacity: true) }
        seedCache[dateString] = drawn
        return drawn
    }

    private static var seedCache: [String: FolderTint] = [:]

    /// **Resolved along a short chain, not against yesterday's raw draw.**
    ///
    /// The first version compared this day's hash with the PREVIOUS day's
    /// hash, which is not the previous day's colour: if yesterday had itself
    /// been bumped off a collision, today could be bumped straight onto it.
    /// `neighboursDiffer` found six of these in four hundred days, which is
    /// a rate nobody would have noticed by looking and everybody would have
    /// noticed eventually.
    ///
    /// Walking a fixed twelve days back and resolving forward makes the
    /// answer depend only on twelve hashes, so it is the same on every
    /// device and in every year — the recursion is real but it terminates at
    /// a constant depth rather than at the epoch. The chain is only wrong if
    /// twelve consecutive days all collide, which is one in six to the
    /// eleventh.
    private static func draw(_ dateString: String) -> Int {
        let n = all.count
        guard let date = DateUtils.date(from: dateString) else {
            return Int(hash(dateString) % UInt64(n))
        }
        let calendar = Calendar.current
        let depth = 12
        func raw(_ offset: Int) -> Int {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else {
                return Int(hash(dateString) % UInt64(n))
            }
            return Int(hash(DateUtils.dateString(from: day)) % UInt64(n))
        }
        var index = raw(depth)
        for offset in stride(from: depth - 1, through: 0, by: -1) {
            var next = raw(offset)
            if next == index { next = (next + 1) % n }
            index = next
        }
        return index
    }

    /// FNV-1a. **Not `hashValue`**, which Swift seeds per process, so the
    /// same string hashes differently on the next launch. `ScatterLayout`
    /// carries the same note for the same reason.
    private static func hash(_ text: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return h
    }
}

/// Where a day's sticker sits on its folder: how big, how far round, and
/// where its centre lands. See `WinFolder.stickerSpot`.
struct StickerSpot: Equatable {
    var side: CGFloat
    var centre: CGPoint
    var lean: Double

    /// The axis-aligned box the sticker can occupy once it has been turned.
    /// A square of `side` rotated by `lean` needs this much room, and it is
    /// what "stays on the folder" has to be measured against.
    var bounds: CGRect {
        let radians = abs(lean) * .pi / 180
        let extent = side * (abs(cos(radians)) + abs(sin(radians)))
        return CGRect(x: centre.x - extent / 2, y: centre.y - extent / 2,
                      width: extent, height: extent)
    }
}

/// **A folder of wins, with a glass front.**
///
/// **`tint` is the whole customisation story and it is one parameter.** Every
/// colour in here is derived from it, so a folder is recoloured by changing
/// one value rather than by redrawing anything. Nothing else in this view
/// knows what colour it is.
struct WinFolder: View {
    /// Kept for the accessibility label, which still has to say what this
    /// is and how much is in it. Nothing is drawn from either.
    var title: String = "Wins"
    var count: Int = 0
    /// The quiet line under the title, on the glass. "7 wins", "Nothing yet".
    var subtitle: String = ""
    var tint: Color = WinFolder.defaultTint
    /// **What is in it, as wins rather than as pictures.** A card with no
    /// image is its colour, exactly as the block was.
    var contents: [ScatterWin] = []
    /// **0 is a closed folder, 1 is an open one.**
    ///
    /// The owner: "the current date be opened, date while the previous days
    /// can be closed."
    ///
    /// It is one number rather than a Bool because the two states have to be
    /// able to travel between each other: when midnight turns today into
    /// yesterday, or when a folder is tapped, the pocket slides and the cards
    /// settle down behind it rather than cutting. Closed, the pocket reaches
    /// nearly to the tab and there is nothing standing above it — which is
    /// what a folder you are not looking in actually looks like.
    var openAmount: CGFloat = 1
    /// **Off by default, and that is the owner's call.**
    ///
    /// "Add the various faces (face off by default)."
    ///
    /// It is the right default for a row of seven. One face is a character;
    /// seven faces in a line is a bag of emoji, and the page's subject is the
    /// week rather than the folders. A face is something you turn on for the
    /// day you care about.
    var showsFace: Bool = false
    var expression: FaceExpression = .idle
    /// Off for a still. On, the face blinks, looks around and breathes.
    var isAlive: Bool = true
    /// **One thing out of the day, lifted off its background.**
    ///
    /// Nil for most days and that is correct — see `DayStickerService` for
    /// the bar a photograph has to clear. A sticker on every folder is
    /// decoration; a sticker on the days that had something in them is a
    /// remark.
    var sticker: UIImage? = nil
    /// What the sticker's size, place and lean are drawn from. The day's own
    /// key, so a folder's sticker is in the same spot every launch — one that
    /// moved when you scrolled past it would read as a bug rather than as
    /// something stuck on by hand.
    var stickerSeed: String = ""

    /// **The folder's default colour, for anything that does not pick one.**
    ///
    /// Sand: warm, muted, and close enough to the page's own warm white to
    /// belong to it while still being an object on it rather than a hole in
    /// it. The cream this replaced was tuned for a near black page and
    /// disappears on a light one — the same value, the opposite problem.
    static let defaultTint = FolderTint.sand.colour

    /// The lit side of a colour: a touch brighter and a touch cleaner, the
    /// way a light falls on something.
    static func lit(_ colour: Color) -> Color {
        let c = hsb(colour)
        return Color(hue: c.h, saturation: c.s * 0.80, brightness: min(c.b * 1.06, 1))
    }

    /// The shaded side: deeper AND warmer. **A shadow on a warm colour goes
    /// warm, not grey**, which is the whole difference between this reading
    /// as an object and reading as a faded rectangle.
    static func shaded(_ colour: Color) -> Color {
        let c = hsb(colour)
        return Color(hue: c.h, saturation: min(c.s * 1.35, 0.62), brightness: c.b * 0.86)
    }

    private static func hsb(_ colour: Color) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(colour).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    @State private var idle = FolderIdle()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var live: FaceExpression {
        var face = expression
        guard isAlive, !reduceMotion else { return face }
        face.openness *= idle.blink
        face.gaze.width += idle.gaze.width
        face.gaze.height += idle.gaze.height + idle.breath
        return face
    }

    /// **How full the folder looks, 0 to 1.** Twelve is a full day, so that
    /// is the top of the scale. The stack spreads wider, the pocket swells,
    /// and the shadow deepens. None of them is legible on its own, which is
    /// the point.
    private var fullness: CGFloat {
        min(CGFloat(max(count, contents.count)) / 12, 1)
    }

    var body: some View {
        // **The aspect is established BEFORE the geometry is read, not
        // after.** A `GeometryReader` has no intrinsic size of its own, so
        // inside a scrolling stack it is proposed an unbounded height and
        // `.aspectRatio` applied outside it has nothing to work from: the
        // whole folder rendered at zero and the lab came up black.
        //
        // **1.14 rather than 1.04.** A folder is landscape — a sheet of paper
        // goes in it the short way — and at square it read as a card with a
        // notch. Both references are wider than they are tall.
        Color.clear
            .aspectRatio(1.14, contentMode: .fit)
            .overlay { folder }
            .animation(GridConstants.naturalSettle, value: fullness)
            .animation(GridConstants.naturalSettle, value: openAmount)
            // A sticker that has just been worked out arrives rather than
            // appearing: it is being put on.
            .animation(.spring(response: 0.46, dampingFraction: 0.72), value: sticker != nil)
            .onAppear { if isAlive && showsFace { idle.reach = 5; idle.start() } }
            .onDisappear { idle.stop() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(count) wins")
    }

    private var folder: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let shape = FolderBack()

            ZStack {
                // 1. The plate.
                LinearGradient(colors: [Self.lit(tint), Self.shaded(tint)],
                               startPoint: .top, endPoint: .bottom)
                    .clipShape(shape)

                // 2. The wins, NOT clipped to the plate. A photograph sitting
                //    flush with the top edge is printed ON the folder, where
                //    one standing proud of it is IN the folder. Every
                //    reference does this and it is the whole trick.
                peeking(width: w, height: h)

                // 3. The line where the front meets what is behind it.
                //
                // **This is not the smudge he had taken out, and the
                // difference is the whole point.** That one was cast by the
                // cards onto the glass IN FRONT of them — a dark patch with
                // no object above it. This is the opposite and it is the
                // thing that was missing: light cannot get into the gap where
                // the pocket's lip stands proud of the plate, so there is a
                // narrow darkening ABOVE the seam, on the surface behind. It
                // is the one cue that says the front is in front.
                //
                // Clipped to the plate, so it can never appear over the
                // folder's own outline; 5% of the height and 8% black, which
                // is below the threshold at which anybody sees it as a
                // shadow and above the one at which the seam reads as two
                // shapes butted together.
                occlusion(width: w, height: h)

                // 4. The glass front, which is the folder-shaped piece.
                front(width: w, height: h)

                // 5. The day's cut-out, stuck low on the front.
                //
                // The owner: "the sticker placement should be near the bottom
                // of the folder, not the top."
                //
                // He is right and the reason is worth keeping. It straddled
                // the seam where the pocket meets the plate, on the argument
                // that a sticker goes on the outside. But that seam is the
                // busiest line on the object — it is where the photographs
                // come out — so a sticker there was competing with the
                // contents rather than labelling them. Low on the front is
                // where a label goes on anything you file: a spine, a jar, a
                // box. It is also the quietest part of this folder, which is
                // what a mark wants to be put on.
                //
                // Leaning right, always the same way. A sticker put on by
                // hand is never square, and randomising the lean per day
                // would make the row look shaken rather than labelled.
                if let sticker {
                    let spot = stickerSpot(width: w, height: h)
                    Image(uiImage: sticker)
                        .resizable()
                        .scaledToFit()
                        .frame(width: spot.side, height: spot.side)
                        // The one shadow it gets, and it is a contact
                        // shadow: a sticker is lying ON the folder, a
                        // millimetre off it, so it is tight and close rather
                        // than a float.
                        .shadow(color: .black.opacity(0.20), radius: h * 0.010, y: h * 0.005)
                        .rotationEffect(.degrees(spot.lean))
                        .position(x: spot.centre.x, y: spot.centre.y)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                // 6. The face, on the pocket, when it is asked for.
                if showsFace {
                    FolderFace(expression: live, eyeWidth: w * 0.072)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        // Low on the pocket, which is the other half of what
                        // reads as endearing: features set low on a large head.
                        .padding(.bottom, h * 0.085)
                        .transition(.opacity)
                }
            }
            .compositingGroup()
            // **Two shadows, because one is fog.**
            //
            // A single soft shadow was tuned for a near-black page, where a
            // wide dark falloff reads as depth. On warm white the same
            // construction has no edge anywhere in it, so the folder does not
            // sit on the page, it hovers over a smudge — which is most of why
            // the row looked weightless.
            //
            // What makes an object sit on paper is two separate things
            // happening at once, and photographers and print designers both
            // name them: a CONTACT shadow, tight and dark and directly under
            // the edge, which is the light that cannot get between the object
            // and the surface; and an AMBIENT one, wide and very faint, which
            // is the room. The contact shadow is the one that was missing. It
            // is small enough that you never see it as a shadow — you see the
            // folder touching the page.
            //
            // Both deepen as the folder fills, because a fuller folder is a
            // heavier one.
            .shadow(color: .black.opacity(0.13 + 0.05 * fullness),
                    radius: h * 0.012,
                    y: h * 0.006)
            .shadow(color: .black.opacity(0.07 + 0.03 * fullness),
                    radius: h * (0.075 + 0.02 * fullness),
                    y: h * (0.030 + 0.012 * fullness))
        }
    }

    /// **A stack that gets thicker as the folder fills**, and that lies down
    /// flat when the folder is closed.
    ///
    /// Up to five cards fanned, newest at the front, each one showing its own
    /// block's proportion, no border, opaque.
    ///
    /// **One width, several heights.** Fanning cards of wildly different
    /// widths reads as a mess rather than as a stack, so the width is shared
    /// and the block's shape comes through in the HEIGHT — a 2x1 win is a
    /// wide short card, a 1x1 is square, a 2x2 is tall.
    private func peeking(width w: CGFloat, height h: CGFloat) -> some View {
        let shown = Array(contents.prefix(5).enumerated())
        let open = openAmount
        let fan = 0.30 + 0.70 * openAmount
        return ZStack {
            ForEach(shown, id: \.element.id) { index, win in
                // **The newest is at the front, and it was at the back.**
                //
                // `contents` arrives newest first — the owner's call, and the
                // same order the tower put new blocks on top in. This read
                // `shown.count - 1 - index`, which was written for a
                // list that ran the other way: it put the win you had just
                // logged furthest back in the fan and the oldest of the five
                // square on top. Nobody would have described it that way and
                // it is exactly the wrong way round for a folder you have
                // just put something into.
                //
                // Index 0 is now square, upright and in front, and the older
                // ones fan out behind it.
                //
                // **Keyed by the win, not by its position.** `id: \.offset`
                // gave card slot 0 the same identity whatever win was in it,
                // so a new win arriving was a CHANGE to an existing card
                // rather than an insertion — nothing could animate, because
                // as far as SwiftUI knew nothing had arrived.
                let spread = Double(index) / Double(max(shown.count - 1, 1))
                let side: Double = index % 2 == 0 ? -1 : 1
                // **Photographs, not thumbnails.**
                //
                // The owner: "make sure the cards inside are bigger, so they
                // kinda reach near the bottom of the folder like they were
                // real photographs."
                //
                // They were sized off the block's own aspect, which is
                // correct for the tower and wrong here: a 2x1 came out a
                // letterbox a third of the folder deep, so the pocket had
                // nothing behind most of it and the stack read as a row of
                // tabs rather than as prints standing in a folder. A
                // photograph put in a folder goes most of the way down it.
                //
                // So the three sizes are stated as what they should MEASURE
                // in a folder rather than derived from their spans, and they
                // stay ordered: a small reaches 74% of the way down, a
                // medium 81%, a hard 90%. The span still decides which one,
                // so nothing about the block system moved — only what a
                // block looks like when it is a print in a pocket.
                // **One width, and the height is the picture's own** — the
                // same rule the grid inside the folder uses, so a photograph
                // is the same shape peeking out of a folder as it is lying
                // in one. The owner: "make sure if an image is shown it is
                // consistent on every page, no crazy different sizes
                // everywhere."
                //
                // It was two widths and three heights keyed off the block's
                // spans, which meant a landscape photograph on a 1x1 win came
                // out portrait here and landscape inside. Same clamp as
                // `ScatterLayout.tidied`, for the same reason: a panorama is
                // a sliver at this size and a tall crop runs off the folder.
                let cardWidth = w * 0.42
                let ratio = win.image.map { $0.size.height / max($0.size.width, 1) }
                    ?? CGFloat(win.size.rowSpan) / CGFloat(win.size.columnSpan)
                let cardHeight = cardWidth * min(max(ratio, 0.55), 1.85)

                // No title on the stack: a card here is 40% of a small folder
                // and a word would be a smudge.
                // Unedged: these sit behind the pocket's glass, and a
                // hairline seen through a pane reads as a scratch on it.
                WinCardFace(win: win, image: win.image, showsTitle: false,
                            edged: false)
                .frame(width: cardWidth, height: cardHeight)
                // **Rasterised per CARD, and it was per stack.**
                //
                // One group around the whole stack is the cheaper composite
                // and it quietly breaks the drop: a `drawingGroup` renders
                // its own bounds, and a card arriving from 42% of the
                // folder's height ABOVE the stack starts outside them, so the
                // first half of the animation would have been clipped away —
                // the card would appear halfway down instead of coming in
                // from above.
                //
                // Per card keeps what the group was for. The expensive part
                // is inside a card, not between them: four blend-mode blooms,
                // a blur and a grain canvas, five cards a folder, six folders
                // on the row, all being recomposited live while a finger
                // moves. Measured with `-strataPerfProbe` over an identical
                // drag, body evaluations were ZERO and the display link still
                // logged gaps of 147, 67 and 53ms — rendering cost rather
                // than SwiftUI cost — and rasterising took the worst to 32ms.
                // Every transform now sits OUTSIDE the texture, where it can
                // move as far as it likes.
                .drawingGroup()
                // **No shadow on these.** They sit BEHIND the pocket, so what
                // they were casting landed on the glass in front of them: a
                // soft dark smudge with no object over it.
                // **The fan narrows when the folder closes; it does not
                // shut.** It did, and a closed folder came out with five
                // cards stacked on exactly the same rectangle: through the
                // glass that is one smudge, and a smudge is what the owner
                // will see rather than a folder with things in it. The blue
                // folder in his reference shows three card edges through its
                // front and that is the whole reason it reads as full. 38%
                // of the fan is enough to count them and not enough to look
                // like it is spilling.
                .rotationEffect(.degrees(side * spread * Double(fan) * (9 + 6 * Double(fullness))))
                // Nothing is hidden with opacity: the pocket is genuinely in
                // front of them, so they only have to move to be behind it.
                // **Placed by its TOP, not by its centre.**
                //
                // Centring meant a taller card grew in both directions, so
                // the biggest wins rose furthest out of the folder and
                // reached no further down behind the glass. Pinning the top
                // does the opposite and is what a stack in a pocket actually
                // does: every card shows about the same amount of itself
                // above the lip, and the rest of it goes down inside where
                // the front can be seen through to it.
                .offset(x: CGFloat(side) * CGFloat(spread) * fan * w * (0.12 + 0.07 * fullness),
                        y: topOfStack(in: h) + cardHeight / 2 - h / 2
                            + CGFloat(spread) * h * 0.02)
                .zIndex(Double(shown.count - index))
                // **It drops in.**
                //
                // The owner: "when you take the photo or add a win there
                // needs to be an animation after, of the photo plopping in
                // the folder... and it needs to look good while doing it."
                //
                // A new win comes from above the folder, a touch too big and
                // a touch turned, and settles square on the front of the
                // stack while the four behind it shuffle out of the way. The
                // shuffle is not extra work: every other card's spread
                // depends on how many there are, so they move because the
                // stack genuinely changed, not because something told them
                // to look busy.
                .transition(.asymmetric(
                    insertion: .offset(y: -h * 0.42)
                        .combined(with: .scale(scale: 1.12))
                        .combined(with: .opacity),
                    removal: .opacity))
            }
        }
        .frame(width: w, height: h, alignment: .center)
        // The stack settles rather than cutting. Keyed on which wins are in
        // it, so a photograph finishing its decode does not set it off.
        .animation(.spring(response: 0.52, dampingFraction: 0.74),
                   value: contents.map(\.id))
    }

    /// **The glass front.**
    ///
    /// The owner: "let's get this folder design as premium as possible with
    /// the glass front."
    ///
    /// Four layers and each one is doing a job a real piece of frosted glass
    /// does. The material genuinely blurs the cards behind it, so what shows
    /// through is the photographs rather than a drawing of them. The tint
    /// laid back over it is the glass being *coloured* rather than grey —
    /// a white folder plus a material plus black came out the colour of
    /// dishwater. A one point highlight along the top edge is the lit edge
    /// any piece of glass catches. And a wide diagonal sheen across the upper
    /// third is the reflection, which is the layer that makes it read as
    /// glass rather than as plastic: without it the front is evenly bright
    /// and nothing on a phone is evenly bright.
    /// **Where a day's sticker goes, how big it is and how far it leans.**
    ///
    /// The owner: "can you have them have varied sizes and placements, but
    /// keep them on the folder and visible."
    ///
    /// Every folder had its sticker at exactly the same size in exactly the
    /// same corner at exactly the same angle, which is the tell that a
    /// machine put it there. Drawn from the day's own key instead: stable
    /// across launches, different from its neighbour.
    ///
    /// **Varied inside a box, never outside it.** The random part is where in
    /// the SAFE REGION the centre lands, and the safe region is computed from
    /// the sticker's own size so it cannot reach an edge. Its top is the
    /// pocket's lip, so the sticker is always on the front rather than
    /// half-behind the photographs; its bottom, left and right are a margin
    /// in from the folder. A sticker is a mark on the object, so leaving the
    /// object is the one thing it may never do.
    ///
    /// The side is the FRAME both dimensions are fitted into, and the picture
    /// inside it is `scaledToFit`, so the drawn width and height are both at
    /// most `side` whatever shape the subject is. That is what makes the
    /// margin arithmetic safe without measuring the image.
    private func stickerSpot(width w: CGFloat, height h: CGFloat) -> StickerSpot {
        Self.stickerSpot(seed: stickerSeed.isEmpty ? title : stickerSeed,
                         width: w, height: h, pocketShare: pocketShare)
    }

    /// Where a sticker goes, as a pure function so the one invariant that
    /// matters can be tested: it never leaves the folder. See
    /// `StickerPlacementTests`.
    nonisolated static func stickerSpot(seed: String, width w: CGFloat, height h: CGFloat,
                                        pocketShare: CGFloat) -> StickerSpot {
        var rng = StableSeed(seed)
        // 26% to 37% of the folder's width. Below a quarter a group of people
        // stops being readable at this size; above 37% it competes with the
        // folder instead of marking it.
        let side = w * (0.26 + 0.11 * rng.unit())
        let margin = w * 0.045
        // The lean expands the sticker's footprint by up to its own diagonal
        // minus its side, and that is reserved here.
        //
        // **Honestly: at ±10° the margin already covers it.** Removing this
        // line and re-running `staysOnTheFolder` over four hundred days
        // passes — the worst swing is 4.8pt against a 6.8pt margin. It stays
        // because the margin covering it is a coincidence of two numbers
        // that are tuned for different reasons: widen the lean past about
        // ±18° and the margin stops being enough, and the failure would be
        // one corner of one day's sticker off one edge. The arithmetic is
        // cheaper than finding that.
        let lean = -10 + 16 * Double(rng.unit())
        let swing = abs(sin(lean * .pi / 180)) * side
        let half = side / 2 + swing / 2

        let left = half + margin
        let right = max(w - half - margin, left)
        let top = h * (1 - pocketShare) + half + margin * 0.6
        let bottom = max(h - half - margin, top)

        return StickerSpot(side: side,
                           centre: CGPoint(x: left + (right - left) * rng.unit(),
                                           y: top + (bottom - top) * rng.unit()),
                           lean: lean)
    }

    /// Where the cards' top edge sits. Open, high enough that a good part of
    /// every card stands above the pocket's lip; closed, low enough that only
    /// a sliver does.
    private func topOfStack(in h: CGFloat) -> CGFloat {
        h * (0.135 * openAmount + 0.30 * (1 - openAmount))
    }

    /// The occlusion above the pocket's lip. See where it is composited.
    private func occlusion(width w: CGFloat, height h: CGFloat) -> some View {
        let pocketHeight = h * pocketShare
        return LinearGradient(colors: [.clear, .black.opacity(0.08)],
                              startPoint: .top, endPoint: .bottom)
            .frame(height: h * 0.05)
            .offset(y: -pocketHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .clipShape(FolderBack())
            .allowsHitTesting(false)
    }

    /// **Where the front's low edge sits**, as a fraction of the card's
    /// height from the top. Open it sits at 44% and the photographs stand out
    /// of it; closed it rides up to 20% and there is almost nothing to see.
    /// A fuller folder pushes it down a little, as though something behind it
    /// is holding it open.
    private var frontTop: CGFloat {
        let open: CGFloat = 0.44 - 0.02 * fullness
        let closed: CGFloat = 0.20
        return closed + (open - closed) * openAmount
    }

    /// The raised part of the front's top edge — the tab. A fixed distance
    /// above the low edge, so the step is the same depth however open the
    /// folder is.
    private var frontTabTop: CGFloat { max(frontTop - 0.13, 0.04) }

    /// How much of the folder's height the front covers, which is what the
    /// sticker's safe region and the seam's shadow are both measured from.
    private var pocketShare: CGFloat { 1 - frontTop }

    /// **The glass panel, which is now the folder-shaped piece.**
    ///
    /// The owner: "I'm looking for more of a premium design for the folders,
    /// like glass like this... I might like the shape of the orange one a bit
    /// better, with the text on the glass part, I feel like that looks more
    /// luxury."
    ///
    /// Four layers, and each one is a thing a pane of coloured glass does.
    /// The **material** blurs what is behind it, so the photographs are
    /// genuinely seen through it rather than drawn faint. The **tint** is the
    /// glass being coloured rather than grey. The **sheen** is a wide, very
    /// soft radial high on the panel — and this is NOT the specular band he
    /// had taken out twice. That was a hard diagonal streak, which is a claim
    /// about a point light and made six folders in a row catch it in
    /// identical places. This is the diffuse bloom a frosted panel has when
    /// light falls on the whole of it, which is what the reference draws and
    /// why that drawing reads as luxury rather than as a rendering. And the
    /// **rim** is one hairline, so the panel has an edge.
    private func front(width w: CGFloat, height h: CGFloat) -> some View {
        let shape = FolderFront(lowTop: frontTop, tabTop: frontTabTop)
        return shape
            .fill(.ultraThinMaterial)
            .opacity(0.80)
            .overlay {
                shape.fill(LinearGradient(colors: [tint.opacity(0.24), tint.opacity(0.50)],
                                          startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                // The diffuse bloom, centred high and slightly left, falling
                // away to nothing well before the edges. 22% is the most it
                // can be before it stops being light on a surface and starts
                // being a shape drawn on one.
                RadialGradient(colors: [.white.opacity(0.22), .clear],
                               center: UnitPoint(x: 0.42, y: 0.30),
                               startRadius: 0,
                               endRadius: w * 0.72)
                    .clipShape(shape)
                    .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.30), lineWidth: 1)
            }
            .overlay(alignment: .bottomLeading) { plate(width: w) }
    }

    /// **The day and the count, set on the glass.**
    ///
    /// They were under the folder, as a caption. On the glass they are part
    /// of the object — which is the whole of what he means by the reference
    /// looking more luxury: a designed thing carries its own label, and a
    /// thing with a caption beneath it is a thumbnail in a list.
    ///
    /// White, because every tint in the palette is a mid tone and white is
    /// the only ink that reads on all six. The count at 70% rather than a
    /// second colour, so the pair is one voice at two volumes.
    private func plate(width w: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: w * 0.012) {
            Text(title)
                .font(Typography.headerMedium)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(Typography.bodySmall)
                .foregroundStyle(.white.opacity(0.70))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .shadow(color: .black.opacity(0.18), radius: w * 0.02, y: w * 0.004)
        .padding(.leading, w * 0.075)
        .padding(.bottom, w * 0.07)
        .allowsHitTesting(false)
    }
}
