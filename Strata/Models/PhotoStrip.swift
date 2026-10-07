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

        static func == (a: Frame, b: Frame) -> Bool { a.id == b.id && a.size == b.size }
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
        Array(candidates.filter { !excluded.contains($0.id) }.prefix(Self.most))
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

    static func isDeveloped(_ owner: PhotoStrip.Owner, day: String) -> Bool {
        defaults.bool(forKey: "strip.developed.\(owner.key).\(day)")
    }

    static func setDeveloped(_ owner: PhotoStrip.Owner, day: String) {
        defaults.set(true, forKey: "strip.developed.\(owner.key).\(day)")
    }

    static var paper: StripPaper {
        get { StripPaper(rawValue: defaults.string(forKey: "strip.paper") ?? "") ?? .black }
        set { defaults.set(newValue.rawValue, forKey: "strip.paper") }
    }
}

/// White or black, and nothing else (the owner: "remove the creme setting
/// only white or black"). Black first, as his own strip is.
enum StripPaper: String, CaseIterable, Identifiable {
    case black, white
    var id: String { rawValue }

    var ground: Color {
        self == .black ? Color(red: 0.07, green: 0.07, blue: 0.07) : Color.white
    }
    var type: Color {
        self == .black ? Color(red: 0.96, green: 0.95, blue: 0.93) : Color(red: 0.12, green: 0.11, blue: 0.10)
    }
    var quiet: Color { type.opacity(0.55) }
    var name: String { self == .black ? "Black" : "White" }
}

// MARK: - Loading

extension PhotoStrip {
    /// **The days before today that have a strip** (the owner, 2026-10-07:
    /// "shouldn't you be able to access the last couple days photo strips"),
    /// newest first: the last week's days with at least one photograph or
    /// doodle, read small. A day with only colour blocks has no strip.
    @MainActor
    static func earlier(days: Int = 7, before today: Date = Date(), context: ModelContext) async -> [PhotoStrip] {
        var strips: [PhotoStrip] = []
        for back in 1...days {
            guard let date = Calendar.current.date(byAdding: .day, value: -back, to: today) else { continue }
            let strip = await mine(day: DateUtils.dateString(from: date), context: context, small: true)
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
                                size: log.habit?.blockSize ?? .small, picture: picture))
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
