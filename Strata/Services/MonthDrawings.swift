import Foundation
import Observation
import PencilKit

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
    nonisolated static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
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
    func save(_ drawing: PKDrawing, canvas: CGSize, bringsToLife: Bool, for month: String) {
        guard !drawing.strokes.isEmpty, canvas.width > 0, canvas.height > 0 else {
            remove(month)
            return
        }
        let old = self.drawing(for: month)
        let picture = "month-\(month)-\(UUID().uuidString.prefix(8)).png"
        guard let png = InkExport.png(of: drawing, in: CGRect(origin: .zero, size: canvas),
                                      scale: JournalSketches.scale) else { return }
        let record = MonthDrawing(strokes: drawing.dataRepresentation(),
                                  canvasWidth: canvas.width, canvasHeight: canvas.height,
                                  bringsToLife: bringsToLife, picture: picture)
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
    /// The sway-settle after the last stroke.
    static let settle: Double = 1.1

    let durations: [Double]
    let starts: [Double]

    init(lengths: [Double], total: Double = Self.total, cap: Double = Self.perStrokeCap) {
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
    /// The whole play: the drawing, then its settle.
    var playDuration: Double { drawDuration + Self.settle }

    /// How much of a stroke shows at `t`, 0 to 1.
    func progress(of stroke: Int, at t: Double) -> Double {
        guard durations.indices.contains(stroke) else { return 1 }
        let d = durations[stroke]
        guard d > 0 else { return t >= starts[stroke] ? 1 : 0 }
        return min(max((t - starts[stroke]) / d, 0), 1)
    }

    /// The settle: one gentle sway of the whole drawing about its foot, in
    /// degrees, `s` seconds after the last stroke. The spring the owner's own
    /// drawings land on (`IllustrationMotion.springOut`), small, and at rest
    /// by `settle`.
    static func sway(at s: Double) -> Double {
        guard s > 0, s < settle else { return 0 }
        let fade = 1 - s / settle
        return 2.4 * IllustrationMotion.springOut(s, frequency: 1.5, damping: 0.3) * fade
    }

    /// The boil: while the strokes are drawing, the whole drawing steps
    /// between three tiny offsets, eight times a second, the way a hand-drawn
    /// frame boils. Zero at rest, always.
    func boil(at t: Double) -> CGSize {
        guard t > 0, t < drawDuration else { return .zero }
        let frames: [CGSize] = [CGSize(width: 0.35, height: -0.25),
                                CGSize(width: -0.3, height: 0.2),
                                CGSize(width: 0.1, height: 0.35)]
        return frames[Int(t * 8) % frames.count]
    }
}
