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
    #Index<HabitLog>([\.dateString])

    var id: UUID = UUID()
    var habit: Habit?
    var dateString: String // YYYY-MM-DD format for easy lookup
    var completed: Bool
    var completedAt: Date?
    var note: String?
    var caption: String
    @Attribute(.externalStorage) var imageData: Data? // Retained temporarily for migration
    var imageFileName: String?
    var imageURL: String?       // Deprecated — retained for schema compatibility
    var videoURL: String?       // Deprecated — retained for schema compatibility
    var imageFlipped: Bool = false  // Deprecated — retained for schema compatibility
    var cropPositionX: Double?  // Deprecated — retained for schema compatibility
    var cropPositionY: Double?  // Deprecated — retained for schema compatibility
    var surgeMode: Bool
    var pendingXP: Int?
    var xpCollected: Bool
    var isBonusBlock: Bool
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
