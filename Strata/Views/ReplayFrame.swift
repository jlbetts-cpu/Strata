import SwiftUI

/// One moment of a replay. No timers, no state: everything comes from
/// `script` at `t`. `ReplayView` draws it live and `ReplayVideoExporter`
/// draws it to frames.
struct ReplayFrame: View {
    let script: ReplayScript
    let images: ReplayImages
    let t: Double
    var now: Date = Date()
    var showsSampleBadge = false
    /// Save Video and Share, supplied live; the exporter passes nothing.
    var controls: AnyView? = nil
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

    private var m: ReplayScript.Metrics { script.metrics }
    private var replay: Replay { script.replay }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WarmBackground()
            // Type BENEATH the tower: a block falling past the running label
            // passes in front of it, as a thing in the scene passes in front
            // of a caption, rather than the word printing across the block.
            topCopy
            tower
            if let onTapBlock { blockTaps(onTapBlock) }
            close
        }
        .frame(width: m.frame.width, height: m.frame.height)
        // **Capped.** The frame's lines (`followY`, `baseY`) are fractions of
        // the frame and cannot grow with the type, so past xxLarge the label
        // ran across the follow line and the close ran off the bottom. The
        // exporter pins `.large`, so the video is the default setting.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    // MARK: Header and running label

    /// The header over the running label, in one column so the label always
    /// sits a fixed gap under whatever the header turned out to be.
    private var topCopy: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            runningLabel
                .padding(.top, GridConstants.gapItem)
        }
        .padding(.leading, GridConstants.horizontalPadding)
        // The same cap line every screen title sits on, measured from the
        // bottom of the frame's safe area.
        .padding(.top, topInset + GridConstants.headerTopPadding(forTitleSize: Self.headerTitleSize))
    }

    /// `Typography.screenSubtitle`'s default size, for the cap arithmetic.
    private static let headerTitleSize: CGFloat = 15

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            // "Sample" rides on the title's own line, in its ink. As a
            // separate darker word it out-shouted the title it qualifies.
            // Two texts, so each is its own thing to VoiceOver: "Your week",
            // "Sample", never "Your week dot Sample".
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(replay.period.title)
                if showsSampleBadge {
                    Text(" · Sample").accessibilityLabel("Sample")
                }
            }
            .font(Typography.screenSubtitle)
            .foregroundStyle(AppColors.inkQuiet)
            Text(replay.period.range(relativeTo: now))
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
        }
        .opacity(script.headerOpacity(at: t))
        .accessibilityElement(children: .combine)
    }

    private var runningLabel: some View {
        let s = script.label(at: t)
        return ZStack(alignment: .topLeading) {
            // Sizes the slot from the font as it is actually set, so the slot
            // is one line tall at any text size and a label changing never
            // moves anything.
            labelText(0).hidden()
            if let p = s.previous { labelText(p).opacity(s.previousOpacity).offset(y: s.previousSlide) }
            if let c = s.current { labelText(c).opacity(s.currentOpacity).offset(y: s.currentSlide) }
        }
        .accessibilityHidden(true)
    }

    private static let labelSize: CGFloat = Typography.screenTitleSize

    @ViewBuilder
    private func labelText(_ day: Int) -> some View {
        let text = replay.period.label(forDay: day)
        if replay.period.kind == .month {
            // The owner's digits; the optical inset lines the ink up with the
            // header's margin, as on the Wins tab.
            Text(text).font(Typography.numeral(Self.labelSize))
                .foregroundStyle(AppColors.inkSecondary)
                .padding(.leading, -GridConstants.tallyOpticalInset)
        } else {
            Text(text).font(Typography.screenTitle).foregroundStyle(AppColors.inkSecondary)
        }
    }

    // MARK: Tower

    private var tower: some View {
        let camera = script.camera(at: t)
        let radius = GridConstants.blockCornerRadius(forCell: m.cell)
        let height = max(script.towerHeight, 1)
        let titleOpacity = titleOpacity(at: camera.scale)
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
                        if let image {
                            photo(image, crop: block.win.crop, width: f.width, height: f.height)
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
        .position(x: m.frame.width / 2, y: m.baseY - height / 2)
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

    private var close: some View {
        VStack(spacing: GridConstants.gapTight) {
            // The words are one element; the controls under them are not
            // part of it. Combined with them, Share became a phrase in the
            // count's sentence rather than a button of its own.
            VStack(spacing: GridConstants.gapTight) {
                // The Wins tab's header, set the same way: the count in the
                // owner's digits, the word a quieter caption beside it.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(replay.count)")
                        .font(Typography.tally)
                        .foregroundStyle(AppColors.inkPrimary)
                        .padding(.leading, -GridConstants.tallyOpticalInset)
                    Text(replay.count == 1 ? "win" : "wins")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkQuiet)
                }
                .opacity(script.closeOpacity(0, at: t))
                if let sentence = replay.sentence() {
                    Text(sentence)
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(script.closeOpacity(1, at: t))
                }
            }
            .accessibilityElement(children: .combine)
            if let controls {
                controls
                    .padding(.top, GridConstants.gapItem)
                    .opacity(script.closeOpacity(2, at: t))
                    .allowsHitTesting(t >= script.closeStart)
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        // Hung from the base, not centred in the space under it. Centred, the
        // controls arriving pushed the count UP toward the tower; hung, the
        // count keeps one distance from the base and the close grows down.
        //
        // Placed by its own laid-out height, so at a large text size it rises
        // just far enough that its bottom stays inside the frame's safe area
        // instead of running off the screen.
        .alignmentGuide(VerticalAlignment.top) { d in
            -min(m.baseY + Self.closeGap - Self.tallyAscent,
                 m.frame.height - bottomInset - Self.closeBottomMargin - d.height)
        }
        .frame(width: m.frame.width, height: m.frame.height, alignment: .top)
    }

    /// The least room left under the close.
    private static let closeBottomMargin: CGFloat = GridConstants.gapTight

    /// From the tower's base to the count's cap.
    private static let closeGap: CGFloat = 40
    /// The count's layout top sits this far above its cap.
    private static let tallyAscent: CGFloat = GridConstants.roundedCapInset * GridConstants.tallyNumeral
}
