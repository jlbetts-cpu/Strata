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

    private var m: ReplayScript.Metrics { script.metrics }
    private var replay: Replay { script.replay }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WarmBackground()
            tower
            topCopy
            close
        }
        .frame(width: m.frame.width, height: m.frame.height)
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
            // "Sample" rides on the title's own line, in its own ink. As a
            // separate darker word it out-shouted the title it qualifies.
            Text(showsSampleBadge ? "\(replay.period.title) · Sample" : replay.period.title)
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
            if let p = s.previous { labelText(p).opacity(s.previousOpacity).offset(y: s.previousSlide) }
            if let c = s.current { labelText(c).opacity(s.currentOpacity).offset(y: s.currentSlide) }
        }
        // A fixed slot, so a label changing never moves anything.
        .frame(height: Self.labelSize * 1.2, alignment: .topLeading)
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
        let titles = camera.scale >= Self.titleScaleFloor
        return ZStack(alignment: .bottomLeading) {
            Color.clear.frame(width: script.gridWidth, height: height)
            ForEach(Array(replay.blocks.enumerated()), id: \.element.id) { index, block in
                let pose = script.pose(index, at: t)
                if pose.visible {
                    let f = script.blockFrame(index)
                    let image = images[block.win.photo]
                    BlockFace(title: block.win.title, category: block.win.category,
                              iconCategory: block.win.category, rowSpan: block.rowSpan,
                              width: f.width, height: f.height, cornerRadius: radius,
                              hasPhoto: image != nil, showOverlay: titles) {
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

    /// Below this camera scale a block's title is dropped.
    ///
    /// Photographed at a month's fitted scale (0.11) every title rendered as a
    /// 2pt grey speck, so a finished month read as a ribbon covered in dust.
    /// At 0.45 `Typography.blockTitle` draws at about 7pt, which is where it
    /// stops being words; a fitted week (0.50) keeps its titles.
    private static let titleScaleFloor: CGFloat = 0.45

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
            if let controls {
                controls
                    .padding(.top, GridConstants.gapItem)
                    .opacity(script.closeOpacity(2, at: t))
                    .allowsHitTesting(t >= script.closeStart)
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .frame(width: m.frame.width)
        // Hung from the base, not centred in the space under it. Centred, the
        // controls arriving pushed the count UP toward the tower; hung, the
        // count keeps one distance from the base and the close grows down.
        .offset(y: m.baseY + Self.closeGap - Self.tallyAscent)
        .accessibilityElement(children: .combine)
    }

    /// From the tower's base to the count's cap.
    private static let closeGap: CGFloat = 40
    /// The count's layout top sits this far above its cap.
    private static let tallyAscent: CGFloat = GridConstants.roundedCapInset * GridConstants.tallyNumeral
}

#if DEBUG
/// Temporary: a replay frozen at `-strataReplayAt`, for screenshots.
/// Task 7 replaces it with `ReplayView`.
struct ReplayDebugFrame: View {
    let replay: Replay
    @State private var images: ReplayImages?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            let script = ReplayScript(replay: replay, metrics: .standard(frame: geo.size),
                                      reduceMotion: false)
            if let images {
                ReplayFrame(script: script, images: images,
                            t: DebugHarness.replayAt ?? script.duration,
                            showsSampleBadge: true,
                            topInset: Self.windowInsets.top)
            }
        }
        .ignoresSafeArea()
        .task {
            let cell = GridConstants.cellSize(forGridWidth: Self.windowWidth - GridConstants.horizontalPadding * 2)
            images = await ReplayImages.load(replay, width: cell * displayScale)
        }
    }

    private static var window: UIWindow? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow
    }
    private static var windowInsets: UIEdgeInsets { window?.safeAreaInsets ?? .zero }
    private static var windowWidth: CGFloat { window?.bounds.width ?? 402 }
}
#endif
