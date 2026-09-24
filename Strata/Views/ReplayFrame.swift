import SwiftUI
import UIKit

/// One moment of a replay. No timers, no state: everything comes from
/// `script` at `t`. `ReplayView` draws it live and `ReplayVideoExporter`
/// draws it to frames.
struct ReplayFrame: View {
    let script: ReplayScript
    let images: ReplayImages
    let t: Double
    /// The one `now` the date is worded against. Required: a
    /// default `Date()` per frame could reword the range mid-play at
    /// midnight, and the still and the video would each pick their own.
    let now: Date
    /// "Sample" after the date once it arrives. The Settings
    /// preview's live replay and its saved video, so a made-up week cannot
    /// be posted as a real one.
    var showsSampleBadge = false
    /// Replay, Save Video and Share, supplied live; the exporter passes
    /// nothing.
    var controls: AnyView? = nil
    /// Live only: how far a photograph that arrived after playback started
    /// has faded in. The exporter waits for every photograph and passes
    /// nothing, so every frame of the video draws each picture whole.
    var photoOpacity: ((ReplayPhoto) -> Double)? = nil
    /// Live only: whether a block's photograph is in or still on its way, so
    /// the block is drawn as a photograph (veil, vignette, title shadow) from
    /// its first frame and only the picture fades in. Without it a block is
    /// drawn as a photograph exactly when its picture is in, which is always
    /// for the exporter and the posters.
    var expectsPhoto: ((ReplayPhoto) -> Bool)? = nil
    /// The frame's top safe-area inset: the status bar and the Dynamic Island
    /// live, or a story-safe margin in the saved video. The header is set
    /// from it. The tower's lines and the controls' row come from the
    /// script's metrics, which were laid out from the same insets.
    var topInset: CGFloat = 0
    /// A tap on a block, by index into `replay.blocks`. Live only, and only
    /// once the close has arrived; the card and the exporter pass nothing,
    /// and then nothing extra is drawn or hit-tested.
    var onTapBlock: ((Int) -> Void)? = nil
    /// VoiceOver's double tap on the header or the close words. Live only.
    /// An action rather than the player's tap gesture: see `ReplayView`.
    var onAccessibilityActivate: (() -> Void)? = nil
    /// The shelf's poster: the tower alone, at a scale and on a base the
    /// caller chose, so a row of posters shares one scale and compares by
    /// height. Nil everywhere else, which draws the replay as it plays.
    var poster: Poster? = nil

    struct Poster: Equatable {
        /// World points to frame points, the same for every card in a row.
        var scale: CGFloat
        /// Where the tower's base stands, in frame points.
        var baseY: CGFloat
    }

    private var m: ReplayScript.Metrics { script.metrics }
    private var replay: Replay { script.replay }

    /// The type size around the frame, capped below as the frame caps its own
    /// content: this view's environment is read outside its own
    /// `.dynamicTypeSize(...xxLarge)`.
    @Environment(\.dynamicTypeSize) private var outerTypeSize

    /// The count's size as the type is actually set, for the digit roll's
    /// window. Scaled from the CAPPED size: a `@ScaledMetric` here read the
    /// uncapped one, so above xxLarge the window was sized for a bigger
    /// digit than the one drawn and shaved the rolling digits.
    private var tallySize: CGFloat {
        let category = UIContentSizeCategory(min(outerTypeSize, .xxLarge))
        return UIFontMetrics(forTextStyle: .largeTitle)
            .scaledValue(for: Typography.screenTitleSize,
                         compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WarmBackground()
            // Type BENEATH the tower: a block falling past the count passes
            // in front of it, as a thing in the scene passes in front of a
            // caption, rather than the number printing across the block.
            if poster == nil { topCopy }
            tower
            if let onTapBlock { blockTaps(onTapBlock) }
            if poster == nil { close }
        }
        .frame(width: m.frame.width, height: m.frame.height)
        // **Capped.** The frame's lines (`followY`, `baseY`) are fractions of
        // the frame and cannot grow with the type, so past xxLarge the label
        // ran across the follow line and the close ran off the bottom. The
        // exporter pins `.large`, so the video is the default setting.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    // MARK: The count and the date

    /// The count over the date, top left.
    ///
    /// **During the build only the count** (the owner, 2026-09-15: "before
    /// that it should just say the win numbers and be counting up as the
    /// blocks place"). It is set as the Wins tab's header, the owner's
    /// digits with the word a quieter caption beside it, and it counts one
    /// landing at a time. **The date arrives with the reveal**, under the
    /// count, which stays the lead. Its line is laid out from the first
    /// frame at opacity 0, so nothing moves when it arrives.
    private var topCopy: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            countLine
            rangeLine
        }
        .padding(.leading, GridConstants.horizontalPadding)
        // The cap line the Wins tab's count sits on, measured from the bottom
        // of the frame's safe area.
        .padding(.top, topInset + GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(topCopyLabel)
        .replayActivation(onAccessibilityActivate)
    }

    /// How tall the count and date stand under the top inset at a text
    /// size: the header's top padding, the count's line, the gap and the
    /// date's line. The script keeps the finished tower's top under it
    /// (`Metrics.standard`). From the system's own line heights for the
    /// styles the lines are set relative to, since the script is made before
    /// anything is laid out.
    static func topCopyHeight(_ size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(min(size, .xxLarge)))
        let count = UIFont.preferredFont(forTextStyle: .largeTitle, compatibleWith: traits).lineHeight
        // The date line is `Typography.screenSubtitle`, a subheadline.
        let title = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits).lineHeight
        return GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral)
            + count + GridConstants.gapTight + title
    }

    /// "31 wins, Your week, 7 to 13 September": the numbers spoken, since
    /// the digits are drawn a position at a time and the range as figures.
    private var topCopyLabel: String {
        let n = script.count(at: t)
        return ["\(n) \(n == 1 ? "win" : "wins")", showsSampleBadge ? "Sample" : nil,
                replay.period.title, replay.period.spokenRange(relativeTo: now)]
            .compactMap { $0 }.joined(separator: ", ")
    }

    /// The range, or a month's name: "9/7-9/13", "September".
    private var rangeText: String { replay.period.range(relativeTo: now) }

    private var countLine: some View {
        let roll = script.countRoll(at: t)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            digits(roll)
                // Optical, as on the Wins tab: a digit's ink starts inside its
                // box, so the box sits a little left of the margin.
                .padding(.leading, -GridConstants.tallyOpticalInset)
            Text(roll.count == 1 ? "win" : "wins")
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkQuiet)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .opacity(script.countOpacity(at: t))
    }

    /// The count, one digit position at a time.
    ///
    /// **An odometer.** Only a position that changes moves: its old digit
    /// rises out of a window the height of the digits' own ink as the new
    /// one rises in from below it, both at full strength. The window is the
    /// cap band (`roundedCapInset` below the line's top, a cap high, with a
    /// little room for round overshoot), not the line box: the owner's face
    /// sets its digits in a line about 1.2 em tall with the ink in the
    /// middle, and clipped to that box, a roll a whole line long showed the
    /// two numbers stacked with a gap between them, "19" over "20". The
    /// digits travel the window's height and a small gap more, so they never
    /// overlap and nothing fades or dims: a frame mid-roll shows the bottom
    /// of the old digit leaving the top of the window and the top of the new
    /// one entering at the bottom, the way a counter wheel looks.
    ///
    /// The owner's digits are tabular, so neighbours never shift; a new
    /// leading digit (9 to 10) opens its width in the first half of the roll,
    /// so "wins" slides over rather than jumping. Under Reduce Motion nothing
    /// travels: the digit changes at the middle of the roll.
    private func digits(_ roll: ReplayScript.CountRoll) -> some View {
        let slots = ReplayScript.digitSlots(roll)
        let e = CGFloat(script.rollEase(roll.progress))
        let still = script.reduceMotion
        let size = tallySize
        let pad = size * Self.rollWindowPad
        let windowTop = GridConstants.roundedCapInset * size - pad
        let windowHeight = Typography.screenTitleCap / Typography.screenTitleSize * size + 2 * pad
        let travel = windowHeight + size * Self.rollGap
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(slots.indices, id: \.self) { i in
                let slot = slots[i]
                WidthReveal(fraction: slot.old == nil && slot.changes && !still ? CGFloat(ReplayScript.rollOpening(Double(e))) : 1) {
                    if slot.changes, !still {
                        ZStack {
                            if let old = slot.old { digit(old).offset(y: -travel * e) }
                            if let new = slot.new { digit(new).offset(y: travel * (1 - e)) }
                        }
                        .mask(alignment: .top) {
                            Rectangle()
                                .frame(height: windowHeight)
                                .padding(.top, windowTop)
                        }
                    } else if slot.changes {
                        // Both laid out, one shown: a leading digit's width
                        // is there from the roll's start, so "wins" does not
                        // step sideways.
                        ZStack {
                            if let old = slot.old { digit(old).opacity(e < 0.5 ? 1 : 0) }
                            if let new = slot.new { digit(new).opacity(e < 0.5 ? 0 : 1) }
                        }
                    } else if let new = slot.new {
                        digit(new)
                    }
                }
                // The part of a still-opening position that is not open yet
                // is not drawn.
                .clipped()
            }
        }
    }

    /// Room above and below the digits' cap band inside the roll's window,
    /// for the round digits' overshoot, as a fraction of the type's size.
    private static let rollWindowPad: CGFloat = 0.06
    /// The space between a leaving digit and an arriving one, as a fraction
    /// of the type's size.
    private static let rollGap: CGFloat = 0.1

    private func digit(_ c: Character) -> some View {
        Text(String(c))
            .font(Typography.tally)
            .foregroundStyle(AppColors.inkPrimary)
    }

    /// The line under the count: the range, or a month's name, in the quiet
    /// ink at the caption size.
    ///
    /// **No "Your week" over it** (the owner, 2026-09-15: the title block
    /// "looks a bit too much"). Four were drawn and looked at: this one; the
    /// range after "wins" on the count's line; the count alone; and "Your
    /// week" with the range in the darker medium weight, which is what
    /// shipped first. This one keeps the count's line exactly as the Wins
    /// tab sets it, and leaves the date as what it is: context under the
    /// fact. The words "Your week" are the app talking about itself, which
    /// the person the video is sent to does not need.
    ///
    /// It arrives up 8pt with opacity as the reveal starts, and a Settings
    /// preview's "Sample" follows it 80ms later.
    private var rangeLine: some View {
        let range = script.titleArrival(0, at: t)
        let badge = script.titleArrival(1, at: t)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(rangeText)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkQuiet)
                .opacity(range.opacity)
                .offset(y: range.offset)
            if showsSampleBadge {
                Text("Sample")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkQuiet)
                    .opacity(badge.opacity)
                    .offset(y: badge.offset)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: Tower

    private var tower: some View {
        let camera = poster.map { ReplayScript.Camera(rise: 0, scale: $0.scale) } ?? script.camera(at: t)
        let radius = GridConstants.blockCornerRadius(forCell: m.cell)
        let height = max(script.towerHeight, 1)
        // A poster is a picture of a tower at a glance: at shelf size a
        // title is a speck, and a row of them reads as dust.
        let titleOpacity = poster == nil ? titleOpacity(at: camera.scale) : 0
        return ZStack(alignment: .bottomLeading) {
            Color.clear.frame(width: script.gridWidth, height: height)
            ForEach(replay.blocks.indices, id: \.self) { index in
                let block = replay.blocks[index]
                let pose = script.pose(index, at: t)
                if pose.visible {
                    let f = script.blockFrame(index)
                    let image = images[block.win.photo]
                    BlockFace(title: block.win.title, category: block.win.category,
                              rowSpan: block.rowSpan,
                              width: f.width, height: f.height, cornerRadius: radius,
                              hasPhoto: image != nil || block.win.photo.map { expectsPhoto?($0) ?? false } == true,
                              showOverlay: titleOpacity > 0,
                              overlayOpacity: titleOpacity) {
                        if let image, let source = block.win.photo {
                            photo(image, crop: block.win.crop, width: f.width, height: f.height)
                                .opacity(photoOpacity?(source) ?? 1)
                        }
                    }
                    .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
                    .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                    .opacity(pose.opacity)
                    .offset(x: f.minX, y: -f.minY + pose.fallOffset + pose.lift)
                }
            }
        }
        .frame(width: script.gridWidth, height: height, alignment: .bottomLeading)
        .scaleEffect(camera.scale, anchor: .bottom)
        .offset(y: camera.rise * camera.scale)
        .position(x: m.frame.width / 2, y: (poster?.baseY ?? m.baseY) - height / 2)
        .accessibilityHidden(true)
    }

    /// One tap layer over the whole tower, hit-tested against where the
    /// script draws each block, rather than a recogniser per block.
    ///
    /// **Why one layer.** A finished month rests at a scale near 0.11, where a
    /// block is 9pt across; the script's `block(at:)` gives every block at
    /// least a finger's target. It is a sibling in the ZStack, not an
    /// overlay: over the close it would take Share's taps, and an optional
    /// sibling leaves the tower's identity alone when it arrives.
    ///
    /// **Why it cannot fight the player's gestures.** A child's tap gesture
    /// wins over an ancestor's, so after the close a tap here is not also the
    /// player's skip; that skip is a no-op there anyway, since it only moves
    /// forward to the close. The player's hold is simultaneous and still runs.
    private func blockTaps(_ onTap: @escaping (Int) -> Void) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { point in
                if let index = script.block(at: point, t: t) { onTap(index) }
            }
            .accessibilityHidden(true)
    }

    /// How strongly block titles draw at a camera scale.
    ///
    /// Photographed at a month's fitted scale (0.11) every title rendered as a
    /// 2pt grey speck, so a finished month read as a ribbon covered in dust.
    /// At 0.45 `Typography.headerMedium` draws at about 8pt, which is where it
    /// stops being words.
    ///
    /// **Faded, not cut:** across scale 0.55 to 0.45, so the saved video has
    /// no one-frame cut. **And decided by where the tower comes to REST:** a
    /// tower whose fitted scale is at or above the floor keeps full titles
    /// throughout. Fading by the live scale alone left the sample week, which
    /// rests at 0.50, with every title at 47% for good, and a finished tower
    /// with ghost-grey titles reads as a rendering fault. Any band would catch
    /// some tower at rest; this way none is.
    private func titleOpacity(at scale: CGFloat) -> Double {
        if script.fitScale >= Self.titleScaleFloor { return 1 }
        return Double(min(max((scale - Self.titleScaleFloor) / Self.titleFade, 0), 1))
    }

    private static let titleScaleFloor: CGFloat = 0.45
    private static let titleFade: CGFloat = 0.10

    /// The crop exactly as `CachedImageView` applies it: offset the FILLED
    /// picture by a fraction of its drawn size, then frame, then clip. Offset
    /// after the frame moves the picture off its own clip and leaves a strip
    /// of the block's colour showing.
    private func photo(_ image: UIImage, crop: CGPoint, width: CGFloat, height: CGFloat) -> some View {
        let size = image.size
        let scale = size.width > 0 && size.height > 0 ? max(width / size.width, height / size.height) : 1
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .offset(x: -crop.x * size.width * scale, y: -crop.y * size.height * scale)
            .frame(width: width, height: height)
            .clipped()
    }

    // MARK: Close

    /// Under the tower once it has danced: the controls, and nothing else.
    ///
    /// **No sentence** (the owner, 2026-09-15): a replay is shared with
    /// friends, and "Thursday was your biggest day" means nothing to them.
    /// The count and the title at the top already say what the tower is. The
    /// video passes no controls, so its close is the tower alone.
    @ViewBuilder
    private var close: some View {
        if let controls {
            let arrival = script.closeArrival(at: t)
            controls
                .opacity(arrival.opacity)
                .offset(y: arrival.offset)
                .allowsHitTesting(t >= script.closeStart)
                .padding(.horizontal, GridConstants.horizontalPadding)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .contain)
                // On the bottom margin the script laid out (`closeTop`), so
                // the row is seated just above the home indicator on every
                // phone and the tower fills the space above it.
                .alignmentGuide(VerticalAlignment.top) { _ in -m.closeTop }
                .frame(width: m.frame.width, height: m.frame.height, alignment: .top)
        }
    }
}

/// Lays its content out at a fraction of its width, trailing-aligned: a
/// digit position opening as the count gains a digit. Its baselines are the
/// content's, so the count's line still sits on "wins".
private struct WidthReveal: Layout {
    var fraction: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        return CGSize(width: size.width * min(max(fraction, 0), 1), height: size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.maxX, y: bounds.minY), anchor: .topTrailing, proposal: .unspecified)
    }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard let first = subviews.first else { return nil }
        return bounds.minY + first.dimensions(in: .unspecified)[guide]
    }
}

private extension View {
    /// The frame's accessibility default action, when the caller gave one.
    @ViewBuilder
    func replayActivation(_ action: (() -> Void)?) -> some View {
        if let action { accessibilityAction(.default, action) } else { self }
    }
}
