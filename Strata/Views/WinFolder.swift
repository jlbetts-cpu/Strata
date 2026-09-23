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
    /// How much of the width the tab takes.
    var tabWidth: CGFloat = 0.42
    /// How far below the tab's top the body sits, as a fraction of height.
    var step: CGFloat = 0.17

    /// The corner radius both the plate and the pocket use. **One number and
    /// one construction**, because they were two: the plate drew quad curve
    /// corners and the pocket used a continuous `RoundedRectangle`, which is
    /// a squircle, so at the same radius they were visibly different shapes
    /// meeting along one edge. The owner: "the corner rounding of the folder
    /// isn't the same rounding of the folder."
    static func radius(in rect: CGRect) -> CGFloat { min(rect.width, rect.height) * 0.072 }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let r = Self.radius(in: rect)
        let bodyTop = rect.minY + h * step
        let tabEnd = rect.minX + w * tabWidth
        // How far right the diagonal travels on its way down, and how much of
        // each end of it is rounded off. The bevel is deliberately a fifth of
        // the corner radius: enough that the join is not a needle point at
        // 1pt of antialiasing, nowhere near enough to read as a curve.
        let run = w * 0.055
        let bevel = min(r * 0.45, run * 0.5)

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: tabEnd - bevel, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: tabEnd + bevel * 0.5, y: rect.minY + bevel * 0.9),
                       control: CGPoint(x: tabEnd, y: rect.minY))
        p.addLine(to: CGPoint(x: tabEnd + run - bevel * 0.5, y: bodyTop - bevel * 0.9))
        p.addQuadCurve(to: CGPoint(x: tabEnd + run + bevel * 0.4, y: bodyTop),
                       control: CGPoint(x: tabEnd + run, y: bodyTop))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: bodyTop))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: bodyTop + r),
                       control: CGPoint(x: rect.maxX, y: bodyTop))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
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

                // 3. The pocket: the glass front, and the hinge.
                pocket(width: w, height: h)

                // 4. The day's cut-out, stuck on the front.
                //
                // **Over the pocket's lip, not inside the pocket.** A sticker
                // is on the OUTSIDE of a folder — that is what makes it a
                // sticker rather than another thing filed in it — so it
                // straddles the seam where the front meets the plate, which
                // is the one place on this object that reads as a surface
                // you would stick something to.
                //
                // Leaning right, always the same way. A sticker put on by
                // hand is never square, and randomising the lean per day
                // would make the row look like it was shaken rather than
                // labelled.
                if let sticker {
                    Image(uiImage: sticker)
                        .resizable()
                        .scaledToFit()
                        .frame(width: w * 0.34, height: h * 0.34)
                        // The one shadow it gets, and it is a contact
                        // shadow: a sticker is lying ON the folder, a
                        // millimetre off it, so the shadow is tight and
                        // close rather than a float.
                        .shadow(color: .black.opacity(0.22), radius: h * 0.012, y: h * 0.006)
                        .rotationEffect(.degrees(-7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topTrailing)
                        .offset(x: -w * 0.05, y: h * 0.20)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                // 5. The face, on the pocket, when it is asked for.
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
            // The one shadow, and it is the folder standing on the ground
            // rather than chrome pretending to float. **Much lighter than it
            // was**, because it is on a warm white page now: 42% black under
            // a folder on near black is a soft falloff, and the same number
            // on a light page is a bruise.
            .shadow(color: .black.opacity(0.10 + 0.05 * fullness),
                    radius: h * (0.055 + 0.015 * fullness),
                    y: h * (0.020 + 0.010 * fullness))
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
            ForEach(shown, id: \.offset) { index, win in
                // The fan opens from the middle outwards, oldest furthest
                // back and widest out, so the newest sits square at the front.
                let depth = Double(shown.count - 1 - index)
                let spread = depth / Double(max(shown.count - 1, 1))
                let side: Double = index % 2 == 0 ? -1 : 1
                let ratio = CGFloat(win.size.rowSpan) / CGFloat(win.size.columnSpan)
                // **The width says the size too, not only the height.**
                //
                // The owner: "make sure the different sizes are shown." It
                // was one shared width with the proportion in the height
                // alone, which reads as one stack of cards that happen to be
                // cropped differently rather than as a small win and a big
                // one. A 2-column block is a quarter wider here — enough to
                // be seen at 150pt, and short of the spread that makes a fan
                // of mixed widths look like a spill.
                let cardWidth = w * (win.size.columnSpan > 1 ? 0.50 : 0.40)
                // **Clamped, so nothing stands proud of the plate.** A 2x2
                // at half the width comes out 75pt tall in a 131pt folder;
                // lifted and tilted, its corners cleared the back plate's own
                // top edge and the folder read as overflowing rather than as
                // full. A card in a folder sticks out of the POCKET, never
                // out of the folder.
                let cardHeight = min(cardWidth * max(0.5, min(ratio, 1.15)), h * 0.50)

                // No title on the stack: a card here is 40% of a small folder
                // and a word would be a smudge.
                WinCardFace(win: win, image: win.image, showsTitle: false,
                            corner: GridConstants.radiusPhotoMiniature)
                .frame(width: cardWidth, height: cardHeight)
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
                // Closed, the stack settles LOW in the folder rather than
                // sitting in the middle of it. Centred, the cards read as a
                // photograph printed on the front; dropped 7% they read as
                // something down inside it that the glass is over — and a
                // closed folder ends up visibly quieter than the open one
                // beside it, which is the whole job of the two states.
                .offset(x: CGFloat(side) * CGFloat(spread) * fan * w * (0.12 + 0.07 * fullness),
                        y: -h * 0.14 * open + h * 0.07 * (1 - open) + CGFloat(spread) * h * 0.02)
                .zIndex(Double(index))
            }
        }
        .frame(width: w, height: h, alignment: .center)
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
    private func pocket(width w: CGFloat, height h: CGFloat) -> some View {
        let radius = FolderBack.radius(in: CGRect(x: 0, y: 0, width: w, height: h))
        // Closed, the pocket comes up to just under the tab's step, so there
        // is nothing to see above it. Open, it sits at 62% and the stack
        // stands out of it.
        let closedHeight: CGFloat = 0.845
        let openHeight: CGFloat = 0.62 + 0.025 * fullness
        let height = h * (closedHeight + (openHeight - closedHeight) * openAmount)

        return PocketShape(radius: radius)
            // **The full material, which is the front he picked.**
            //
            // The owner, comparing this row against the dark cream folder
            // with the face on it: "the glass front looked better in the one
            // with the eyes." It did, and the difference was here — that
            // build used `.ultraThinMaterial` at full strength under a tint
            // at 0.70 falling to 0.52. I had cut the material to half and
            // flipped the gradient the other way up chasing transparency,
            // which let the cards through and lost the frost that made it
            // read as a pane rather than a wash. His two notes are not in
            // conflict: the transparency he liked in the reference is the
            // card shapes being VISIBLE through the front, and that survives
            // the full material now that the stack fans even when the folder
            // is shut.
            .fill(.ultraThinMaterial)
            .overlay {
                PocketShape(radius: radius)
                    // Shaded with the folder's own colour, not with black.
                    // The shade comes from taking the tint DOWN rather than
                    // from adding a second colour, which is how a real shadow
                    // on a warm surface behaves.
                    // Heavier at the TOP, which is the way round the build
                    // he picked had it: the lip of a pocket is the doubled
                    // edge of the card stock and the part of it furthest from
                    // what is behind it, so it is the most opaque place on
                    // the front rather than the least.
                    // **Down again, on his read of the row rather than of a
                    // reference:** "make the front of the folder a bit more
                    // transparent so you can kinda see the images in the
                    // folder." The material behind this is still at full
                    // strength — that is the frost he asked to keep — so what
                    // comes off here is the colour laid over it, not the
                    // blur. Measured against the build he liked: 0.70/0.52
                    // down to 0.56/0.42, a fifth less tint, with the same
                    // top-heavy fall.
                    .fill(LinearGradient(colors: [tint.opacity(0.56), tint.opacity(0.42)],
                                         startPoint: .top, endPoint: .bottom))
            }
            // **No sheen, and taking it out is the fix.**
            //
            // A diagonal `plusLighter` band ran across the upper third here,
            // on the argument that a reflection is what separates glass from
            // a frosted rectangle. The owner: "the glass on the front of the
            // folders has a random shine... it should be just premium, you
            // kinda did that with the eye one but then changed it, the
            // original eye had that premium look that I wanted, like the
            // blurred glass look, no bright light on it or anything."
            //
            // He is right and the argument was wrong. A specular highlight
            // implies a POINT light and a fixed angle, so six folders in a
            // row all catch it in the same place and the row reads as a
            // rendering rather than as objects on a page. Frosted glass is
            // diffuse by definition — that is what frosting does to a
            // reflection — so a sheen on it is a contradiction, not a
            // finish. What makes it read as glass is the blur behind it and
            // the one lit edge, which is what the build he liked had.
            .overlay {
                // The lit top edge a pocket catches, and the only hairline
                // here. It is what stops the pocket reading as a rectangle
                // pasted over the plate.
                PocketShape(radius: radius)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
            }
            .frame(height: height)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
