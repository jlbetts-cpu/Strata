import SwiftData
import SwiftUI

/// **The day's photo strip, the goal's reward** (the owner, 2026-10-06: "you
/// know those photo sheets you can get at the mall i want it so if you hit
/// your goal it prints out a sheet of that day and you can save it share
/// customize it as a reward", and "the completion animation [should] print
/// out the photo strip" from the middle of the header, which "could turn into
/// a liquid glass printer").
///
/// A booth strip: paper, up to four frames of the day's wins in the order
/// they landed (a photograph, or the block's colour with its name, as the
/// tower draws it), and the date at the foot under the app's mark. Printed by
/// `GoalCrest` when the goal is crossed; opened from there to keep, share,
/// and choose its paper.
struct DayStrip: Equatable, Identifiable {
    struct Frame: Equatable, Identifiable {
        let id: UUID
        let title: String
        let colour: HabitCategory
        var photo: UIImage?

        static func == (a: Frame, b: Frame) -> Bool { a.id == b.id && (a.photo == nil) == (b.photo == nil) }
    }

    let day: String
    var frames: [Frame]
    var id: String { day }

    /// A booth prints four.
    static let most = 4

    /// Today's wins, first to last, as frames, their photographs loaded.
    @MainActor
    static func today(context: ModelContext, now: Date = Date()) async -> DayStrip {
        let day = DateUtils.dateString(from: now)
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString == day && $0.completed })
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = ((try? context.fetch(d)) ?? [])
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
            .prefix(most)
        var frames: [Frame] = []
        for log in logs {
            let title = log.habit?.title ?? ""
            var frame = Frame(id: log.id,
                              title: title == QuickWinService.untitled ? "" : title,
                              colour: log.habit?.displayCategory ?? .unlabeled)
            if let name = log.imageFileName {
                frame.photo = await ImageManager.shared.loadFullImage(fileName: name)
                    .map { ImageManager.resizeIfNeeded($0, maxDimension: 900) }
            }
            frames.append(frame)
        }
        return DayStrip(day: day, frames: frames)
    }
}

/// The paper a strip is printed on: the owner's "customize".
enum StripPaper: String, CaseIterable, Identifiable {
    case white, warm, ink
    var id: String { rawValue }

    var ground: Color {
        switch self {
        case .white: Color(red: 1, green: 1, blue: 1)
        case .warm: Color(red: 0.98, green: 0.95, blue: 0.89)
        case .ink: AppColors.inkPrimary
        }
    }
    var type: Color { self == .ink ? Color(red: 0.98, green: 0.97, blue: 0.95) : AppColors.inkPrimary }
    var name: String {
        switch self {
        case .white: "White"
        case .warm: "Warm"
        case .ink: "Ink"
        }
    }
}

/// The strip itself, at a width; everything inside is a share of it, so the
/// one in the header and the one kept are the same picture.
struct DayStripView: View {
    let strip: DayStrip
    var paper: StripPaper = .white
    var width: CGFloat = 108
    /// The hairline, on screen; a saved picture is its paper and no more.
    var edged = true

    private var margin: CGFloat { width * 0.074 }
    private var frameSide: CGFloat { width - 2 * margin }

    var body: some View {
        VStack(spacing: margin) {
            ForEach(strip.frames) { frame in
                StripFrameView(frame: frame, side: frameSide)
            }
            footer
        }
        .padding(margin)
        .frame(width: width)
        .background(paper.ground)
        .clipShape(RoundedRectangle(cornerRadius: width * 0.03, style: .continuous))
        // White paper on a white page: the app's hairline, never a shadow.
        .overlay {
            if edged {
                RoundedRectangle(cornerRadius: width * 0.03, style: .continuous)
                    .strokeBorder(GridConstants.fillHairline, lineWidth: 1)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: margin * 0.4) {
            if let mark = UIImage(named: "BrandCamera")?.withRenderingMode(.alwaysTemplate) {
                Image(uiImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.16, height: width * 0.16)
            }
            Text(Self.date(strip.day))
                .font(.system(size: width * 0.085, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(paper.type)
        .padding(.vertical, margin * 0.4)
        .accessibilityElement(children: .combine)
    }

    static func date(_ key: String) -> String {
        guard let date = DateUtils.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

private struct StripFrameView: View {
    let frame: DayStrip.Frame
    let side: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let photo = frame.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                frame.colour.style.baseColor
                if !frame.title.isEmpty {
                    Text(frame.title)
                        .font(.system(size: side * 0.11, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .padding(side * 0.08)
                }
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .accessibilityLabel(frame.title.isEmpty ? "A win" : frame.title)
    }
}

/// **The strip, kept**: shown large, its paper chosen, saved or shared.
struct DayStripSheet: View {
    let strip: DayStrip
    @AppStorage("stripPaper") private var paperRaw = StripPaper.white.rawValue
    @State private var saved = false
    @Environment(\.dismiss) private var dismiss

    private var paper: StripPaper { StripPaper(rawValue: paperRaw) ?? .white }

    var body: some View {
        NavigationStack {
            VStack(spacing: GridConstants.gapSection) {
                Spacer(minLength: 0)
                DayStripView(strip: strip, paper: paper, width: 170)
                Spacer(minLength: 0)
                HStack(spacing: GridConstants.gapLabel) {
                    ForEach(StripPaper.allCases) { option in
                        Button {
                            HapticsEngine.lightTap()
                            paperRaw = option.rawValue
                        } label: {
                            Circle()
                                .fill(option.ground)
                                .overlay { Circle().strokeBorder(GridConstants.fillHairline, lineWidth: 1) }
                                .padding(option == paper ? 0 : 4)
                                .frame(width: 34, height: 34)
                                .background {
                                    if option == paper {
                                        Circle().strokeBorder(AppColors.inkPrimary, lineWidth: 2).padding(-4)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.press)
                        .accessibilityLabel("\(option.name) paper")
                        .accessibilityAddTraits(option == paper ? .isSelected : [])
                    }
                }
                HStack(spacing: GridConstants.gapLabel) {
                    if let image = rendered {
                        ShareLink(item: Image(uiImage: image),
                                  preview: SharePreview(DayStripView.date(strip.day), image: Image(uiImage: image))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: GlassIconButton.defaultSide)
                        }
                        Button {
                            Task {
                                if await PhotoLibrarySaver.save(image, respectingPreference: false) {
                                    HapticsEngine.success()
                                    saved = true
                                }
                            }
                        } label: {
                            Label(saved ? "Saved" : "Save", systemImage: saved ? "checkmark" : "square.and.arrow.down")
                                .frame(maxWidth: .infinity, minHeight: GlassIconButton.defaultSide)
                        }
                        .disabled(saved)
                    }
                }
                .font(Typography.headerMedium)
                .foregroundStyle(AppColors.inkPrimary)
                .buttonStyle(.pressWord)
                .padding(.horizontal, GridConstants.horizontalPadding)
            }
            .padding(.bottom, GridConstants.gapWide)
            // No title: the date is on the strip, and a second one over it
            // would say it twice.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("Done").sheetAction() }
                        .buttonStyle(.pressWord)
                }
            }
            .onChange(of: paperRaw) { _, _ in saved = false }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
    }

    /// The strip as a picture, at three times its print width.
    private var rendered: UIImage? {
        let renderer = ImageRenderer(content: DayStripView(strip: strip, paper: paper, width: 360, edged: false))
        renderer.scale = 3
        return renderer.uiImage
    }
}
