import SwiftData
import SwiftUI

/// **The day's photo strip** (spec: `docs/superpowers/specs/2026-10-06-photo-strip-booth.md`).
///
/// The owner: "the strip needs to feel like our app, it's like its main
/// representation". A booth strip packed the way the tower is: frames take
/// the tower's sizes, two columns wide, in the day's order; only wins with a
/// picture go in (a photograph, or a doodle on its block's colour), never a
/// plain colour block; up to eight, chosen by you.
struct PhotoStrip: Identifiable, Equatable {
    struct Frame: Identifiable, Equatable {
        let id: UUID
        let title: String
        let size: BlockSize
        let picture: UIImage
        /// **A doodle, drawn whole.** A doodle is drawn on its block's square
        /// well, and a lone Quick takes a 2:1 row: filled, it lost its top
        /// and bottom quarters (the 2026-10-08 audit). Fitted, with its own
        /// colour either side.
        var isDoodle = false
        /// Where the frame's window sits on the photo, moved in the strip's
        /// editor (`CropEditor`, `StripKeeping.crops`). Zero is the middle.
        var crop: CGPoint = .zero
        /// How far in that window is (`PhotoWindow`). One is the photo filled.
        var zoom: CGFloat = 1

        static func == (a: Frame, b: Frame) -> Bool {
            a.id == b.id && a.size == b.size && a.crop == b.crop && a.zoom == b.zoom
        }
    }

    /// Whose strip: yours, or a crew's.
    enum Owner: Equatable, Hashable {
        case me
        case crew(String)

        var key: String {
            switch self {
            case .me: "me"
            case .crew(let id): "crew-\(id)"
            }
        }
    }

    let owner: Owner
    let day: String
    /// Every frame the day could hold, chosen or not, in the day's order.
    var candidates: [Frame]
    /// The signature at the foot: your name, or the crew's.
    var signature: String

    var id: String { "\(owner.key)-\(day)" }

    /// A booth prints eight at most.
    static let most = 8

    /// The frames on the strip: the chosen ones, at most `most`.
    func frames(excluding excluded: Set<UUID>) -> [Frame] {
        let crops = StripKeeping.crops(owner, day: day)
        let zooms = StripKeeping.zooms(owner, day: day)
        return candidates.filter { !excluded.contains($0.id) }.prefix(Self.most).map { frame in
            var frame = frame
            frame.crop = crops[frame.id] ?? .zero
            frame.zoom = zooms[frame.id] ?? 1
            return frame
        }
    }
}

// MARK: - Layout

/// **The strip packed as the tower is** (the spec's table): a Quick is half
/// the width and square, beside the next Quick; a Regular is the full width
/// at 2:1; a Deep is the full width at 4:3. A Quick with no partner takes the
/// full width at 2:1. Order is the day's, except that a Quick waits for the
/// next Quick to sit beside it.
enum StripLayout {
    enum Row: Equatable {
        case pair(Int, Int)
        /// A frame across the strip, and its width over its height.
        case full(Int, aspect: Double)
    }

    static func rows(_ sizes: [BlockSize]) -> [Row] {
        var rows: [Row] = []
        var used = Set<Int>()
        for i in sizes.indices where !used.contains(i) {
            used.insert(i)
            switch sizes[i] {
            case .small:
                if let j = sizes.indices.first(where: { $0 > i && !used.contains($0) && sizes[$0] == .small }) {
                    used.insert(j)
                    rows.append(.pair(i, j))
                } else {
                    rows.append(.full(i, aspect: 2))
                }
            case .medium: rows.append(.full(i, aspect: 2))
            case .hard: rows.append(.full(i, aspect: 4.0 / 3.0))
            }
        }
        return rows
    }
}

// MARK: - What is kept

/// The strip's choices and state, per owner and day: which frames are left
/// out, whether it has been developed, and its paper.
@MainActor
enum StripKeeping {
    private static var defaults: UserDefaults { .standard }

    static func excluded(_ owner: PhotoStrip.Owner, day: String) -> Set<UUID> {
        Set((defaults.stringArray(forKey: "strip.out.\(owner.key).\(day)") ?? []).compactMap(UUID.init))
    }

    static func setExcluded(_ ids: Set<UUID>, _ owner: PhotoStrip.Owner, day: String) {
        defaults.set(ids.map(\.uuidString).sorted(), forKey: "strip.out.\(owner.key).\(day)")
    }

    /// Where each photo was moved to in its frame, for this strip. Beside
    /// the model, as which photos are on it is: a strip is not a row.
    static func crops(_ owner: PhotoStrip.Owner, day: String) -> [UUID: CGPoint] {
        let raw = defaults.dictionary(forKey: "strip.crop.\(owner.key).\(day)") as? [String: [Double]] ?? [:]
        var out: [UUID: CGPoint] = [:]
        // Two numbers, or three since a photo could be zoomed (`zooms`).
        for (key, value) in raw where value.count >= 2 {
            if let id = UUID(uuidString: key) { out[id] = CGPoint(x: value[0], y: value[1]) }
        }
        return out
    }

    /// How far each photo was zoomed in its frame: the third number beside
    /// its crop, there only when it was zoomed.
    static func zooms(_ owner: PhotoStrip.Owner, day: String) -> [UUID: CGFloat] {
        let raw = defaults.dictionary(forKey: "strip.crop.\(owner.key).\(day)") as? [String: [Double]] ?? [:]
        var out: [UUID: CGFloat] = [:]
        for (key, value) in raw where value.count >= 3 {
            let zoom = PhotoWindow.zoom(CGFloat(value[2]))
            if let id = UUID(uuidString: key), zoom > 1 { out[id] = zoom }
        }
        return out
    }

    /// **A win's photo was replaced or removed**: where it was moved to and
    /// how far it was zoomed, on every strip of that day (yours and each
    /// crew's), was said of the old picture. Keyed by the win, it stayed, and
    /// the new photo came up zoomed to three round a point chosen on another
    /// (found by review, 2026-10-13).
    static func forgetWindow(of win: UUID, day: String) {
        let id = win.uuidString
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("strip.crop.") && key.hasSuffix(".\(day)") {
            guard var raw = defaults.dictionary(forKey: key), raw[id] != nil else { continue }
            raw[id] = nil
            defaults.set(raw, forKey: key)
        }
    }

    static func setCrops(_ crops: [UUID: CGPoint], zooms: [UUID: CGFloat] = [:],
                         _ owner: PhotoStrip.Owner, day: String) {
        var raw: [String: [Double]] = [:]
        for id in Set(crops.keys).union(zooms.keys) {
            let point = crops[id] ?? .zero
            let zoom = PhotoWindow.zoom(zooms[id] ?? 1)
            // The middle of the whole photo is not kept: it is what nothing means.
            guard point != .zero || zoom > 1 else { continue }
            raw[id.uuidString] = zoom > 1 ? [point.x, point.y, zoom] : [point.x, point.y]
        }
        defaults.set(raw, forKey: "strip.crop.\(owner.key).\(day)")
    }

    static func isDeveloped(_ owner: PhotoStrip.Owner, day: String) -> Bool {
        defaults.bool(forKey: "strip.developed.\(owner.key).\(day)")
    }

    static func setDeveloped(_ owner: PhotoStrip.Owner, day: String) {
        defaults.set(true, forKey: "strip.developed.\(owner.key).\(day)")
    }

    /// **The paper follows the phone until somebody picks one** (the owner,
    /// 2026-10-08: "the default photostrip on light should actually be light
    /// and on dark it would be dark"). White in light, black in dark; a paper
    /// chosen with the colour button is kept and wins from then on.
    static func paper(for scheme: ColorScheme) -> StripPaper {
        chosenPaper ?? (scheme == .dark ? .black : .white)
    }

    /// **A new key, on purpose.** The old `strip.paper` was written every time
    /// a strip opened, chosen or not, so on every install it holds whatever
    /// the default was then and cannot be told from a choice.
    static var chosenPaper: StripPaper? { StripPaper(rawValue: defaults.string(forKey: "strip.paper.chosen") ?? "") }

    /// Only the colour button calls this: opening a strip never fixes the
    /// paper it happened to open on.
    static func choose(_ paper: StripPaper) {
        defaults.set(paper.rawValue, forKey: "strip.paper.chosen")
    }
}

/// **The strip's paper: black, white, or a block's own colour** (the owner,
/// 2026-10-06: "remove the creme setting, only white or black"; then
/// 2026-10-07: "it would be neat if you could change the color of the card
/// ... any of the category colors or the dark or white version, make it all
/// one button"). Black first, as his own strip is. A coloured strip is lit
/// from inside as a block is (`EtherealFill`), so a strip of a day's wins
/// can be one more block of that day.
enum StripPaper: String, CaseIterable, Identifiable {
    case black, white, health, work, creativity, focus, social, mindfulness
    var id: String { rawValue }

    /// The block colour it is, if it is one.
    var category: HabitCategory? { HabitCategory(rawValue: rawValue) }

    var ground: Color {
        if let category { return category.style.baseColor }
        return self == .black ? Color(red: 0.07, green: 0.07, blue: 0.07) : Color.white
    }
    /// What the paper is filled with: flat for black and white, lit from
    /// inside for a colour.
    var fill: AnyShapeStyle {
        if let category { return AnyShapeStyle(EtherealFill.fill(category.style.baseColor)) }
        return AnyShapeStyle(ground)
    }
    /// The foot's type: white on a colour, as a block's title is.
    var type: Color {
        if category != nil { return .white }
        return self == .black ? Color(red: 0.96, green: 0.95, blue: 0.93) : Color(red: 0.12, green: 0.11, blue: 0.10)
    }
    var quiet: Color { category != nil ? Color.white.opacity(0.8) : type.opacity(0.55) }
    /// Ink drawn on it is light (on black and on a colour) or dark (on white).
    var lightInk: Bool { self != .white }
    var name: String { category?.rawValue.capitalized ?? (self == .black ? "Black" : "White") }

    /// The next paper, for the colour button's tap.
    var next: StripPaper {
        let all = Self.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
}

// MARK: - Loading

extension PhotoStrip {
    /// **The strips you printed, of these days**, newest first (the owner,
    /// 2026-10-07: "the this week and today's strip section should be
    /// combined, and if they didn't develop it or print it out it shouldn't
    /// be showing"). Only a strip that was developed is a strip: a day with
    /// pictures that never reached its goal, or reached it and was never
    /// shaken, has nothing here. Read small.
    static func printed(on days: [String], context: ModelContext) async -> [PhotoStrip] {
        var strips: [PhotoStrip] = []
        for day in days.sorted(by: >) where StripKeeping.isDeveloped(.me, day: day) {
            let strip = await mine(day: day, context: context, small: true)
            if !strip.candidates.isEmpty { strips.append(strip) }
        }
        return strips
    }

    /// Your strip for a day: the day's wins that carry a picture.
    @MainActor
    /// `small` reads thumbnails, for a strip drawn a few points wide: a week
    /// of strips at full size was hundreds of megabytes for a row of stamps.
    static func mine(day: String = DateUtils.dateString(from: Date()), context: ModelContext,
                     small: Bool = false, files: InkFiles = .shared) async -> PhotoStrip {
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString == day && $0.completed })
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = ((try? context.fetch(d)) ?? [])
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        var frames: [Frame] = []
        for log in logs {
            guard let picture = await picture(for: log, small: small, files: files) else { continue }
            let title = log.habit?.title ?? ""
            frames.append(Frame(id: log.id, title: title == QuickWinService.untitled ? "" : title,
                                size: log.habit?.blockSize ?? .small, picture: picture,
                                isDoodle: log.imageFileName == nil))
        }
        let name = ProfileStore.shared.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return PhotoStrip(owner: .me, day: day, candidates: frames,
                          signature: name.split(separator: " ").first.map(String.init) ?? "")
    }

    /// A win's picture: its photograph, or its doodle on its block's colour.
    /// A plain block has none, and stays off the strip, so a win whose
    /// doodle was taken off leaves the strip with it (`DoodledBlockTests`
    /// holds both halves).
    @MainActor
    static func picture(for log: HabitLog, small: Bool = false, files: InkFiles = .shared) async -> UIImage? {
        if let name = log.imageFileName {
            if small {
                return await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: 160, lane: .prefetch)
            }
            if let photo = await ImageManager.shared.loadFullImage(fileName: name) {
                return ImageManager.resizeIfNeeded(photo, maxDimension: 1100)
            }
        }
        if let doodle = log.doodleFileName,
           let data = BlockDoodles.crewPicture(doodle, colour: log.habit?.displayCategory ?? .unlabeled,
                                               files: files) {
            return UIImage(data: data)
        }
        return nil
    }
}
