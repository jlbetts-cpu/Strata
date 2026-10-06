import Foundation
import SwiftData

@Model
final class MoodLog {
    // Four of these carried no default. See the note at the top of `Habit`:
    // CloudKit's mirroring refuses a non-optional attribute with nothing to
    // fall back on, a default is not part of the version hash, and the
    // initialiser still assigns all four, so nothing moves.
    //
    // `imageURL` and `videoURL` were dead, and nothing outside `DebugHarness`
    // made a `MoodLog` at all. Both were kept when CloudKit went on; the
    // reasoning is the block in `Habit`. Since 2026-10-05 they carry the
    // journal's emoji and sketch: see `symbol` and `sketchFileName` below.
    var id: UUID = UUID()
    var dateString: String = "" // YYYY-MM-DD format
    /// 3, the middle of the scale, because a mood with no value in it is not
    /// an awful one. The initialiser clamps and assigns, so nothing reads it.
    var mood: Int = 3          // 1-5 (1=awful, 5=great)
    var motivation: Int = 3    // 1-5
    var note: String?
    var imageURL: String?
    var videoURL: String?

    // MARK: - The day's journal
    //
    // **A `MoodLog` is the day's journal entry now** (2026-10-05, approved by
    // the owner in `docs/superpowers/specs/2026-10-05-shared-wins-journal-doodles-design.md`,
    // section 2). One per `dateString`, made only by `DayNotes`. The model was
    // unused, it was already in the CloudKit schema and it already syncs
    // through the private database, so the journal costs no schema change.
    //
    // **The two accessors below are names over two dead columns, not new
    // fields.** Adding, renaming or retyping a stored property here changes
    // the CloudKit schema, which can only ever gain fields once it is
    // deployed. `videoURL` and `imageURL` were never read and are both
    // optional strings, which is exactly what an emoji and a file name are.
    // The column names lie; these say what is in them. Nothing outside this
    // file should read `videoURL` or `imageURL` on a `MoodLog`.
    //
    // `mood` and `motivation` are not used. The emoji is "the day's *symbol*,
    // not a mood score, so it carries no scale and no chart", and a 1-to-5
    // the journal never asks for stays at its harmless middle.

    /// The day's emoji, chosen in the journal and shown in the corner of the
    /// day's calendar cell. Stored in `videoURL`, a dead column. An empty
    /// string reads as none, so clearing it can never leave a blank badge.
    var symbol: String? {
        get { videoURL.flatMap { $0.isEmpty ? nil : $0 } }
        set { videoURL = newValue.flatMap { $0.isEmpty ? nil : $0 } }
    }

    /// The day's sketch, a PNG beside the photographs, by file name. Stored in
    /// `imageURL`, a dead column. Nothing draws it yet: the sketch strip is
    /// the next part of the spec, and this is the seam it lands on.
    var sketchFileName: String? {
        get { imageURL.flatMap { $0.isEmpty ? nil : $0 } }
        set { imageURL = newValue.flatMap { $0.isEmpty ? nil : $0 } }
    }

    /// Whether there is anything in it. A day whose note was written and then
    /// cleared keeps its row, empty, and is drawn as a day with no note.
    var hasContent: Bool {
        !(note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || symbol != nil || sketchFileName != nil
    }

    init(
        dateString: String,
        mood: Int,
        motivation: Int,
        note: String? = nil
    ) {
        self.id = UUID()
        self.dateString = dateString
        self.mood = min(max(mood, 1), 5)
        self.motivation = min(max(motivation, 1), 5)
        self.note = note
    }
}
