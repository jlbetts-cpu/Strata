import Foundation

/// What the widget draws, written by the app and read by the extension.
///
/// **A file, not the SwiftData store.** A widget could be given the real
/// container through an App Group, and that is the obvious design, but it is
/// the wrong one here for two reasons. Moving an existing store into a group
/// container is a migration of the user's real photographs and wins, and
/// `SharedModelContainer` falls back to an in-memory store SILENTLY when a
/// migration fails — which presents as an empty app rather than a crash.
/// Second, a widget gets a few tens of megabytes and a few hundred
/// milliseconds; standing up SwiftData, fetching, and packing a tower inside
/// that budget is a gamble taken every time the home screen redraws.
///
/// So the app writes a few hundred bytes of already-decided facts, and the
/// widget only draws. Nothing to migrate, nothing to fail.
struct WidgetSnapshot: Codable, Equatable {

    /// One block, already sized and coloured — the widget makes no decisions.
    struct Block: Codable, Equatable {
        /// Cells across and down, from `BlockSize`.
        let columns: Int
        let rows: Int
        /// The category's colour as `RRGGBB`, so the widget needs no access to
        /// `HabitCategory` and the two targets share no code.
        let hex: String
        /// A thumbnail inside the group container, if this win has a
        /// photograph.
        ///
        /// **Copied, not referenced.** The app's photographs live in its own
        /// documents directory, which the widget cannot read at all — a
        /// different process with a different container. So the few that the
        /// widget will actually draw are re-encoded small and written beside
        /// this file. The originals are never moved or touched.
        var photo: String?
    }

    /// Where those thumbnails live, inside the group container.
    static var photoDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-photos", isDirectory: true)
    }

    /// How wide a widget thumbnail is exported, in pixels.
    ///
    /// **Sized to the widget, not to a block.** This was 128, which covered a
    /// 38pt block at 3x back when the widget drew a little tower of them. The
    /// widget is now one photograph filling the frame — a small widget is
    /// about 170pt, so 510px at 3x — and a 128px file stretched across it is a
    /// 4x upscale: "the quality looks so low." It was.
    ///
    /// 600 covers that with headroom for the largest phones, and a JPEG at
    /// this size is still tens of kilobytes. Today's photographs only.
    static let photoPixels: CGFloat = 600

    /// Every win ever logged. The number on the tower's header.
    let total: Int
    /// Logged today, which is the only figure that changes while you watch.
    let today: Int
    /// Consecutive days, from `Streaks.current`.
    let streak: Int
    /// Newest last, capped — a widget shows the top of the tower, not all of
    /// it, and the cap is what keeps this file small enough to be free to
    /// write on every save.
    let blocks: [Block]
    /// Today's photographs, newest first, as file names in `photoDirectory`.
    ///
    /// The widget cycles these. Derived rather than stored twice: it is just
    /// `blocks` reversed and filtered, but naming it here keeps the widget
    /// from having to know that the block order is oldest-first.
    var photos: [String] { blocks.reversed().compactMap(\.photo) }
    let updated: Date

    static let empty = WidgetSnapshot(total: 0, today: 0, streak: 0,
                                      blocks: [], updated: .distantPast)

    /// How many blocks are worth carrying. The largest widget shows far fewer;
    /// the rest is headroom so a bigger widget never needs a new contract.
    static let blockCap = 24

    // MARK: - Where it lives

    /// The App Group both targets can reach.
    ///
    /// If the group is not configured — a fresh checkout, a build without the
    /// entitlement — every accessor here returns nil rather than trapping, and
    /// the widget shows its empty state. A missing widget is a small problem;
    /// a crashing one is reported to the user by the system.
    static let appGroup = "group.JaydenBetts.Strata"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func read() -> WidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    /// Writes only when something actually changed.
    ///
    /// `refreshData()` is a hot path that runs on every save, and asking
    /// WidgetKit to reload a timeline it has already drawn is work the system
    /// charges against the widget's budget — do it often enough and the
    /// updates get throttled, which shows up as a stale tower.
    @discardableResult
    func writeIfChanged() -> Bool {
        guard let url = Self.fileURL else { return false }
        var previous = Self.read()
        // The timestamp always differs, so it cannot take part in the
        // comparison or every write would look like a change.
        previous = WidgetSnapshot(total: previous.total, today: previous.today,
                                  streak: previous.streak, blocks: previous.blocks,
                                  updated: updated)
        guard previous != self else { return false }
        guard let data = try? JSONEncoder().encode(self) else { return false }
        try? data.write(to: url, options: .atomic)
        return true
    }
}
