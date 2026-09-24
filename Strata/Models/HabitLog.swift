import Foundation
import SwiftData

struct SubTask: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var completed: Bool = false
}

@Model
final class HabitLog {
    /// Indexed on `dateString` because History pages through the record a week
    /// at a time with a range predicate on it. Without the index that page is
    /// a table scan of every log ever written. Additive: the store migrates in
    /// place.
    ///
    /// **Not a CloudKit index and not a blocker for one.** `#Index` is a local
    /// SQLite index; CloudKit keeps its own indexes and does not inherit this
    /// one. It stays exactly as it is.
    #Index<HabitLog>([\.dateString])

    // Six of these carried no default. See the note at the top of `Habit`:
    // CloudKit's mirroring refuses a non-optional attribute with nothing to
    // fall back on, a default is not part of the version hash, and the
    // initialiser still assigns all six, so nothing moves.
    //
    // Five fields on this model are dead: `imageURL`, `videoURL`,
    // `imageFlipped`, `pendingXP` and `verifiedByHealthKit`, plus `surgeMode`,
    // `xpCollected` and `isBonusBlock`, which only `StoreRecordDigest` reads.
    // They were kept when CloudKit went on, deliberately; the reasoning and the
    // condition for ever removing them is the one block in `Habit`, so that
    // there is one copy of it.
    var id: UUID = UUID()
    var habit: Habit?
    var dateString: String = "" // YYYY-MM-DD format for easy lookup
    var completed: Bool = false
    var completedAt: Date?
    var note: String?
    var caption: String = ""
    /// Optional, so it already satisfies the rule. `.externalStorage` is also
    /// the right shape for bytes under sync: they travel as an asset rather
    /// than inline in the record. Kept exactly as it is.
    @Attribute(.externalStorage) var imageData: Data? // Retained temporarily for migration
    var imageFileName: String?
    var imageURL: String?       // Deprecated — retained for schema compatibility
    var videoURL: String?       // Deprecated — retained for schema compatibility
    var imageFlipped: Bool = false  // Deprecated — retained for schema compatibility
    /// **Which part of the photograph the block shows**, as a fraction away
    /// from its middle, set by dragging the crop on the camera's review. Nil
    /// is the middle, which is every win nobody moved.
    ///
    /// These two were dead fields kept for schema compatibility. They are the
    /// right name for what the owner asked for — "you should be able to move
    /// the crop on the photo using a basic moving" — so they carry it rather
    /// than a third column meaning the same thing.
    var cropPositionX: Double?
    var cropPositionY: Double?
    var surgeMode: Bool = false
    var pendingXP: Int?
    var xpCollected: Bool = false
    var isBonusBlock: Bool = false
    var skipped: Bool = false
    var verifiedByHealthKit: Bool = false
    var subtasks: [SubTask] = []

    /// Where this block sits in the tower, when you have moved it.
    ///
    /// Nil means "wherever it landed" — the tower packs in completion order,
    /// which is the right default because that is the order the day actually
    /// happened in. Dragging a block writes an explicit position for every
    /// block in the tower, so the arrangement survives the next launch and the
    /// next drop.
    ///
    /// Defaulted rather than optional-with-migration: SwiftData adds it in
    /// place, and every existing log keeps nil, which is the behaviour they
    /// already had.
    var towerOrder: Int? = nil

    // MARK: - Where

    /// Where the photograph was taken, if the app knew at the time.
    ///
    /// **Three flat `Double?`s, not a coordinate type and not a `Codable`
    /// struct.** SwiftData stores `Double?` natively and can PREDICATE on it,
    /// which is the whole reason the map can fetch `latitude != nil` the way
    /// the shelf already fetches `imageFileName != nil`. A composite is an
    /// opaque blob that cannot appear in a `#Predicate` at all. And
    /// `CLLocationCoordinate2D` is not `Codable`, so storing one would drag
    /// CoreLocation into the model layer and make this untestable without the
    /// framework.
    ///
    /// Defaulted rather than optional-with-migration, exactly like
    /// `towerOrder` above: SwiftData adds the columns in place and every
    /// existing log keeps nil, which is the truth about them — no photograph
    /// taken before this shipped has a place, and none ever will. Every path
    /// into `ImageManager` re-encodes a resized `UIImage` with no metadata
    /// container, so there is nothing to recover.
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// Horizontal accuracy in metres, kept so the map can refuse to draw a pin
    /// that is vaguer than the ground it would sit on. Without it a
    /// reduced-accuracy fix puts a confident block in the wrong
    /// neighbourhood.
    var locationAccuracy: Double? = nil

    // MARK: - When, for anybody else

    /// When the win was LOGGED, as opposed to `completedAt`, which is when it
    /// happened. A seeded or back-dated win has the two far apart, and anything
    /// that ever orders arrivals for someone else needs the first.
    ///
    /// These three are here now, before any social feature exists, because the
    /// CloudKit schema is add-only once it is live and one migration with one
    /// backfill is cheaper than two. Defaulted, so existing rows gain them in
    /// place; `SocialFieldsBackfill` sets `createdAt` and `updatedAt` on those
    /// rows from `completedAt` once.
    var createdAt: Date = Date()
    /// Stamped on every save by `StoreStamp`. See `Habit.updatedAt`.
    var updatedAt: Date = Date()
    /// The zone the win was logged in, as `TimeZone.identifier`.
    ///
    /// `dateString` is right for the person who logged it, but it is a local
    /// day with no zone, so nobody else can recover which day a "Sunday" was.
    /// Empty means unknown: every win logged before this shipped, which is the
    /// truth about them.
    var timeZoneIdentifier: String = ""

    var hasDrawerContent: Bool {
        (note != nil && !note!.isEmpty)
        || !caption.isEmpty
        || !subtasks.isEmpty
        || imageFileName != nil
    }

    init(
        habit: Habit,
        dateString: String,
        completed: Bool = false
    ) {
        self.habit = habit
        self.dateString = dateString
        self.completed = completed
        self.completedAt = completed ? Date() : nil
        self.caption = ""
        self.surgeMode = false
        self.xpCollected = false
        self.isBonusBlock = false
        self.skipped = false
        self.timeZoneIdentifier = TimeZone.current.identifier
    }

    func markCompleted() {
        completed = true
        completedAt = Date()
    }

    func markIncomplete() {
        completed = false
        completedAt = nil
    }
}
