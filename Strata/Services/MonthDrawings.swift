import Foundation
import Observation
import PencilKit
import UIKit

/// **Your own drawing for a month** (spec section 4, approved 2026-10-05).
///
/// One per calendar month, keyed "2026-10": the strokes, the canvas they
/// were drawn on, the "Bring It to Life" switch, and the name of a cached
/// template PNG. Two files in `InkFiles`, beside the photographs:
/// `month-2026-10.json` (this) and `month-2026-10-<stamp>.png` (the picture).
///
/// **The default drawing is never touched.** A month with no file shows the
/// owner's own art (`MemoriesView.monthArt`, October's scarecrow and crow
/// with its animation), and "Use Original" is a delete of these two files
/// and nothing else.
nonisolated struct MonthDrawing: Codable, Equatable, Sendable {
    /// `PKDrawing.dataRepresentation()`.
    var strokes: Data
    /// The canvas the strokes were drawn on, in points: the replay scales
    /// from it to the page, so the drawing lands where it was drawn.
    var canvasWidth: Double
    var canvasHeight: Double
    /// "Bring It to Life", on by default (spec section 4, "The editor").
    var bringsToLife: Bool = true
    /// The cached template PNG's file name.
    var picture: String
    /// **Your own line under it**, as the owner's drawings have theirs (the
    /// owner, 2026-10-06: "when you are drawing your own you can add you own
    /// quote"). Optional, so a drawing saved before there were lines still
    /// reads.
    var line: String? = nil
    /// **Stickers on it** (the owner, 2026-10-06: "make it so you can add
    /// stickers to doodles when you are drawing them"), in canvas points.
    /// Drawn into `picture` under the ink, and popped in by the replay once
    /// the lines are drawn. Optional, so a drawing saved before stickers
    /// still reads.
    var stickers: [InkSticker]? = nil

    var canvasSize: CGSize { CGSize(width: canvasWidth, height: canvasHeight) }
}

@MainActor
@Observable
final class MonthDrawingStore {
    static let shared = MonthDrawingStore(files: .shared)

    @ObservationIgnored let files: InkFiles
    /// Read in a body that shows a month drawing, so a save or a "Use
    /// Original" draws again.
    private(set) var revision = 0
    @ObservationIgnored private var cache: [String: MonthDrawing?] = [:]

    init(files: InkFiles) { self.files = files }

    /// "2026-10": the calendar month a date falls in, in the calendar given.
    /// Gregorian numbers in `calendar`'s zone, as every key is
    /// (`DateUtils.keyFormatter`, 2026-10-08).
    nonisolated static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = DateUtils.keyCalendar(in: calendar.timeZone).dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    nonisolated static func recordName(_ month: String) -> String { "month-\(month).json" }

    /// The month's own drawing, or nil for the default.
    func drawing(for month: String) -> MonthDrawing? {
        _ = revision
        if let hit = cache[month] { return hit }
        let found = files.read(Self.recordName(month))
            .flatMap { try? JSONDecoder().decode(MonthDrawing.self, from: $0) }
            // A record whose picture is gone is no drawing: the default shows.
            .flatMap { files.exists($0.picture) ? $0 : nil }
        cache[month] = .some(found)
        return found
    }

    func hasDrawing(for month: String) -> Bool { drawing(for: month) != nil }

    func pictureURL(for month: String) -> URL? { drawing(for: month).map { files.url($0.picture) } }

    /// Keeps a drawing for the month, replacing any before it. An empty
    /// drawing keeps nothing and removes what was there: drawn and rubbed
    /// out is the original again.
    func save(_ drawing: PKDrawing, stickers: [InkSticker] = [], canvas: CGSize, bringsToLife: Bool,
              line: String? = nil, for month: String,
              images: (String) -> UIImage? = InkStickers.image) {
        guard !drawing.strokes.isEmpty || !stickers.isEmpty, canvas.width > 0, canvas.height > 0 else {
            remove(month)
            return
        }
        let old = self.drawing(for: month)
        let picture = "month-\(month)-\(UUID().uuidString.prefix(8)).png"
        guard let png = InkExport.png(of: drawing, stickers: stickers, in: CGRect(origin: .zero, size: canvas),
                                      scale: JournalSketches.scale, images: images) else { return }
        let record = MonthDrawing(strokes: drawing.dataRepresentation(),
                                  canvasWidth: canvas.width, canvasHeight: canvas.height,
                                  bringsToLife: bringsToLife, picture: picture,
                                  line: DrawingLine.kept(line),
                                  stickers: stickers.isEmpty ? nil : stickers)
        do {
            try files.write(png, named: picture)
            try files.write(try JSONEncoder().encode(record), named: Self.recordName(month))
        } catch {
            NSLog("[month] the drawing did not save: \(error)")
            files.remove(picture)
            return
        }
        if let old, old.picture != picture { files.remove(old.picture) }
        cache[month] = .some(record)
        revision += 1
    }

    /// "Use Original": the month's files go, and the default shows again.
    func remove(_ month: String) {
        if let old = drawing(for: month) { files.remove(old.picture) }
        files.remove(Self.recordName(month))
        cache[month] = .some(nil)
        revision += 1
    }
}

/// **The draw-on replay's clock, as arithmetic** (spec section 4, "The
/// animation"). The strokes play back in the order they were drawn, each
/// along its own length, time-compressed so the whole drawing takes about
/// 1.8s; no stroke may take more than its cap, so one long line cannot hold
/// the rest of the drawing back.
///
/// A stroke's share of the time is its length's share of the drawing's
/// length. A share over the cap is cut to the cap and what it gave up is
/// shared among the rest by length, again, until nothing is over: so the
/// total is exactly `total` unless every stroke is at its cap, when it is
/// shorter, never longer.
nonisolated struct InkReplayTiming: Equatable, Sendable {
    static let total: Double = 1.8
    static let perStrokeCap: Double = 0.6
    /// **No sway and no boil** (the owner, 2026-10-06: "I dont like the
    /// drawing animation with the shake it doesnt give off premium to me").
    /// The drawing draws itself on once, in the order it was drawn, and
    /// then holds perfectly still. The settle that swung it about its foot
    /// and the three-frame jitter while it drew are both gone.

    /// **Stickers pop in once the lines are drawn** (2026-10-06): each grows
    /// from a little under its size to its size over `stickerPop`, a beat
    /// after the one before, so they land like stickers pressed on in turn.
    static let stickerPop: Double = 0.34
    static let stickerStagger: Double = 0.09

    let durations: [Double]
    let starts: [Double]
    /// How many stickers pop in after the lines.
    let stickers: Int

    init(lengths: [Double], stickers: Int = 0, total: Double = Self.total, cap: Double = Self.perStrokeCap) {
        self.stickers = stickers
        // A dot has no length and still has to appear: a floor of a point.
        let weights = lengths.map { max($0, 1) }
        var durations = Array(repeating: 0.0, count: weights.count)
        var open = Set(weights.indices)
        var left = total
        while !open.isEmpty {
            let weight = open.reduce(0) { $0 + weights[$1] }
            let over = open.filter { left * weights[$0] / weight > cap }
            if over.isEmpty {
                for i in open { durations[i] = left * weights[i] / weight }
                break
            }
            for i in over { durations[i] = cap; left -= cap }
            open.subtract(over)
        }
        var starts: [Double] = []
        var clock = 0.0
        for d in durations { starts.append(clock); clock += d }
        self.durations = durations
        self.starts = starts
    }

    /// When the last stroke is finished.
    var drawDuration: Double { zip(starts, durations).map { $0 + $1 }.max() ?? 0 }
    /// The whole play: the drawing, then its stickers, and nothing after.
    var playDuration: Double {
        stickers == 0 ? drawDuration
            : drawDuration + Self.stickerStagger * Double(stickers - 1) + Self.stickerPop
    }

    /// How far sticker `index` has popped in at `t`, 0 to 1.
    func pop(of index: Int, at t: Double) -> Double {
        let start = drawDuration + Self.stickerStagger * Double(index)
        return min(max((t - start) / Self.stickerPop, 0), 1)
    }

    /// The sticker's size at pop `p`, a little under its own to its own,
    /// overshooting by a hair on the way (an ease out with a small back).
    static func popScale(_ p: Double) -> Double {
        guard p < 1 else { return 1 }
        let c = 1.4, q = p - 1
        return 0.7 + 0.3 * (1 + (c + 1) * q * q * q + c * q * q)
    }

    /// How much of a stroke shows at `t`, 0 to 1.
    func progress(of stroke: Int, at t: Double) -> Double {
        guard durations.indices.contains(stroke) else { return 1 }
        let d = durations[stroke]
        guard d > 0 else { return t >= starts[stroke] ? 1 : 0 }
        return min(max((t - starts[stroke]) / d, 0), 1)
    }

}

/// **Your own line under the month's original drawing** (the owner,
/// 2026-10-06: "maybe it can be changed for those that want to keep the
/// scarecrow but change the quote"). One a month, by "2026-10", kept on this
/// phone. A drawing of your own carries its line in `MonthDrawing.line`.
@MainActor
@Observable
final class MonthLines {
    static let shared = MonthLines(defaults: .standard)

    @ObservationIgnored private let defaults: UserDefaults
    /// Read where a line is shown, so a change draws again.
    private(set) var revision = 0

    init(defaults: UserDefaults) { self.defaults = defaults }

    nonisolated static func key(_ month: String) -> String { "monthLine.\(month)" }

    func line(for month: String) -> String? {
        _ = revision
        return defaults.string(forKey: Self.key(month))
    }

    /// Kept as `DrawingLine.kept` shapes it; nothing left is the original.
    func set(_ typed: String?, for month: String) {
        if let line = DrawingLine.kept(typed) {
            defaults.set(line, forKey: Self.key(month))
        } else {
            defaults.removeObject(forKey: Self.key(month))
        }
        revision += 1
    }
}
