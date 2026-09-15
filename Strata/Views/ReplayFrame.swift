import SwiftUI
import UIKit

/// One moment of a replay. No timers, no state: everything comes from
/// `script` at `t`. `ReplayView` draws it live and `ReplayVideoExporter`
/// draws it to frames.
struct ReplayFrame: View {
    let script: ReplayScript
    let images: ReplayImages
    let t: Double
    /// The one `now` the title's range is worded against. Required: a
    /// default `Date()` per frame could reword the range mid-play at
    /// midnight, and the still and the video would each pick their own.
    let now: Date
    /// "Sample" beside the count, on every frame. The Settings preview's
    /// live replay and its saved video, so a made-up week cannot be posted
    /// as a real one.
    var showsSampleBadge = false
    /// Replay, Save Video and Share, supplied live; the exporter passes
    /// nothing.
    var controls: AnyView? = nil
    /// Live only: how far a photograph that arrived after playback started
    /// has faded in. The exporter waits for every photograph and passes
    /// nothing, so every frame of the video draws each picture whole.
    var photoOpacity: ((ReplayPhoto) -> Double)? = nil
    /// The frame's top safe-area inset: the status bar and the Dynamic Island
    /// live, or a story-safe margin in the saved video. The header is set
    /// from it; the tower's lines are fractions of the frame.
    var topInset: CGFloat = 0
    /// The home indicator live; 0 or a story-safe margin in the video. The
    /// close never runs past it.
    var bottomInset: CGFloat = 0
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

    /// The count's size as the type is actually set, for the digit roll's
    /// travel: a fraction of the digits, at any text size.
    @ScaledMetric(relativeTo: .largeTitle) private var tallySize: CGFloat = Typography.screenTitleSize

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

    // MARK: The count and the title

    /// The count over the title, top left.
    ///
    /// **During the build only the count** (the owner, 2026-09-15: "before
    /// that it should just say the win numbers and be counting up as the
    /// blocks place"). It is set as the Wins tab's header, the owner's
    /// digits with the word a quieter caption beside it, and it counts one
    /// landing at a time. **The title arrives with the reveal**, under the
    /// count, which stays the lead. Its line is laid out from the first
    /// frame at opacity 0, so nothing moves when it arrives.
    private var topCopy: some View {
        VStack(alignment: .leading, spacing: GridConstants.gapTight) {
            countLine
            titleLine
        }
        .padding(.leading, GridConstants.horizontalPadding)
        // The cap line the Wins tab's count sits on, measured from the bottom
        // of the frame's safe area.
        .padding(.top, topInset + GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(topCopyLabel)
        .replayActivation(onAccessibilityActivate)
    }

    /// How tall the count and title stand under the top inset at a text
    /// size: the header's top padding, the count's line, the gap and the
    /// title's line. The script keeps the finished tower's top under it
    /// (`Metrics.standard`). From the system's own line heights for the
    /// styles the lines are set relative to, since the script is made before
    /// anything is laid out.
    static func topCopyHeight(_ size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(min(size, .xxLarge)))
        let count = UIFont.preferredFont(forTextStyle: .largeTitle, compatibleWith: traits).lineHeight
        let title = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: traits).lineHeight
        return GridConstants.headerTopPadding(forTitleSize: GridConstants.tallyNumeral) + count + GridConstants.gapTight + title
    }

    /// "31 wins, Your week, 7 to 13 September": the numbers spoken, since
    /// the digits are drawn a position at a time and the range as figures.
    private var topCopyLabel: String {
        let n = script.count(at: t)
        return ["\(n) \(n == 1 ? "win" : "wins")", showsSampleBadge ? "Sample" : nil,
                replay.period.title, replay.period.spokenRange(relativeTo: now)]
            .compactMap { $0 }.joined(separator: ", ")
    }

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
            if showsSampleBadge {
                Text("· Sample")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkQuiet)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .opacity(script.countOpacity(at: t))
    }

    /// The count, one digit position at a time. A position that changes
    /// rolls: the old digit rises out as the new one rises in from below,
    /// crossing in opacity. The digits are tabular, so every position is the
    /// same width and the number never shifts sideways inside itself.
    private func digits(_ roll: ReplayScript.CountRoll) -> some View {
        let slots = ReplayScript.digitSlots(roll)
        let e = script.rollEase(roll.progress)
        let rise = script.reduceMotion ? 0 : script.pacing.rollRise * tallySize
        return HStack(spacing: 0) {
            ForEach(slots.indices, id: \.self) { i in
                let slot = slots[i]
                ZStack {
                    if slot.changes {
                        if let old = slot.old {
                            digit(old).opacity(1 - e).offset(y: -rise * CGFloat(e))
                        }
                        if let new = slot.new {
                            digit(new).opacity(e).offset(y: rise * CGFloat(1 - e))
                        }
                    } else if let new = slot.new {
                        digit(new)
                    }
                }
            }
        }
    }

    private func digit(_ c: Character) -> some View {
        Text(String(c))
            .font(Typography.tally)
            .foregroundStyle(AppColors.inkPrimary)
    }

    /// "Your week" in the quiet weight, the range beside it: "9/7-9/13", or
    /// "September". Each arrives up 8pt with opacity, 80ms apart.
    private var titleLine: some View {
        let title = script.titleArrival(0, at: t)
        let range = script.titleArrival(1, at: t)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(replay.period.title)
                .font(Typography.screenSubtitle)
                .foregroundStyle(AppColors.inkQuiet)
                .opacity(title.opacity)
                .offset(y: title.offset)
            Text(replay.period.range(relativeTo: now))
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .opacity(range.opacity)
                .offset(y: range.offset)
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
                              iconCategory: block.win.category, rowSpan: block.rowSpan,
                              width: f.width, height: f.height, cornerRadius: radius,
                              hasPhoto: image != nil, showOverlay: titleOpacity > 0,
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
    /// At 0.45 `Typography.blockTitle` draws at about 7pt, which is where it
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
                // Hung from the base, a fixed gap under it, and raised only as
                // far as it takes to keep clear of the home indicator.
                .alignmentGuide(VerticalAlignment.top) { d in
                    -min(m.baseY + Self.closeGap,
                         m.frame.height - bottomInset - Self.closeBottomMargin - d.height)
                }
                .frame(width: m.frame.width, height: m.frame.height, alignment: .top)
        }
    }

    /// The least room left under the close.
    private static let closeBottomMargin: CGFloat = GridConstants.gapTight

    /// From the tower's base to the top of the controls.
    private static let closeGap: CGFloat = 32
}

private extension View {
    /// The frame's accessibility default action, when the caller gave one.
    @ViewBuilder
    func replayActivation(_ action: (() -> Void)?) -> some View {
        if let action { accessibilityAction(.default, action) } else { self }
    }
}
