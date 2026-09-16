import Testing
import Foundation
import SwiftData
@testable import Strata

/// **Thirty one properties were given default values, and nothing may move.**
///
/// CloudKit's mirroring refuses a schema in which a non-optional attribute has
/// no default, so ten properties on `Habit`, six on `HabitLog`, four on
/// `MoodLog`, five on `Tower` and six on `PlanFolder` were given one. The
/// argument for that being safe is that a default is not part of Core Data's
/// version hash: nothing is renamed, removed or retyped, so the store opens in
/// place and every row keeps every value it already had.
///
/// That is a claim. These measure it: write a full record to a real file,
/// close the container completely, open the file again, and compare a digest
/// over every value a default could have flattened.
///
/// The other half of the check is the one a test cannot do: a store written by
/// a build from BEFORE the change. That is `-strataReportMigration`, which
/// prints the same reading from `StoreRecordDigest` on a real launch, so the
/// old build's line and the new build's line can be put side by side.
@MainActor
@Suite("StoreMigration", .serialized)
struct StoreMigrationTests {

    private func temporaryStore() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("strata-migration-\(UUID().uuidString).store")
    }

    private func container(at url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(schema: SharedModelContainer.schema, url: url))
    }

    /// A record with something in every field a default was added to, plus the
    /// three that would be the loudest loss: the photograph a win names, where
    /// it was taken, and where it sits in the tower.
    private func seedEverything(_ context: ModelContext) throws {
        let tower = Tower(name: "Home", emoji: "🧱", order: 3)
        context.insert(tower)
        let folder = PlanFolder(name: "Errands", icon: "bag.fill", colorHex: "#FF8800", sortOrder: 2)
        context.insert(folder)

        for i in 0..<6 {
            let habit = Habit(
                title: "Win \(i)",
                category: HabitCategory.selectable[i % HabitCategory.selectable.count],
                blockSize: [BlockSize.small, .medium, .hard][i % 3],
                frequency: [.mo, .we, .fr],
                reminderEnabled: i.isMultiple(of: 2),
                isTodo: true,
                graceDays: i)
            habit.tower = tower
            habit.planFolder = folder
            habit.creationXP = i * 5
            habit.spontaneousCategoryRaw = i == 1 ? HabitCategory.work.rawValue : nil
            context.insert(habit)

            let log = HabitLog(habit: habit, dateString: "2026-09-0\(i + 1)", completed: true)
            log.caption = "caption \(i)"
            log.imageFileName = "photo-\(i).heic"
            log.towerOrder = i
            log.latitude = 51.5074 + Double(i) * 0.001
            log.longitude = -0.1278
            log.locationAccuracy = 25
            log.note = i == 0 ? "a note" : nil
            log.surgeMode = i == 2
            log.xpCollected = i == 3
            log.isBonusBlock = i == 4
            log.subtasks = [SubTask(title: "step \(i)", completed: i.isMultiple(of: 2))]
            context.insert(log)
        }

        let mood = MoodLog(dateString: "2026-09-01", mood: 5, motivation: 2, note: "good day")
        context.insert(mood)
        let item = PlanItem(text: "Call the landlord", order: 4, category: .work)
        item.repeatDays = [2, 4]
        context.insert(item)

        try context.save()
    }

    @Test("a store written and closed reads back identically, value for value")
    func recordSurvivesAReopen() throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url) }

        var written = StoreRecordDigest.Reading()
        do {
            let first = try container(at: url)
            let context = ModelContext(first)
            try seedEverything(context)
            written = StoreRecordDigest.read(context: context)
        }

        // A second container over the same file, so the values come off disk
        // rather than out of the first context's memory.
        let second = try container(at: url)
        let reread = StoreRecordDigest.read(context: ModelContext(second))

        #expect(reread.logs == 6)
        #expect(reread.habits == 6)
        #expect(reread.moods == 1)
        #expect(reread.towers == 1)
        #expect(reread.folders == 1)
        #expect(reread.planItems == 1)
        #expect(written.isComplete)
        #expect(reread.isComplete)
        #expect(reread.digest == written.digest)
        #expect(reread == written)
    }

    @Test("a default never overwrites a value that was already there")
    func defaultsDoNotFlatten() throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let first = try container(at: url)
            try seedEverything(ModelContext(first))
        }

        let context = ModelContext(try container(at: url))
        let logs = try context.fetch(FetchDescriptor<HabitLog>())
            .sorted { $0.dateString < $1.dateString }
        #expect(logs.count == 6)
        // Every photograph reference still resolves to the name it was given.
        #expect(logs.map { $0.imageFileName ?? "-" }
                == (0..<6).map { "photo-\($0).heic" })
        // The defaults are `""` and `false`. If one had been applied over a
        // stored value these would be empty and all-false.
        let captioned = logs.filter { !$0.caption.isEmpty }.count
        let completed = logs.filter(\.completed).count
        let surging = logs.filter(\.surgeMode).count
        let collected = logs.filter(\.xpCollected).count
        let bonus = logs.filter(\.isBonusBlock).count
        let ordered = logs.filter { $0.towerOrder != nil }.count
        let placed = logs.filter { $0.latitude != nil }.count
        #expect(captioned == 6)
        #expect(completed == 6)
        #expect(surging == 1)
        #expect(collected == 1)
        #expect(bonus == 1)
        #expect(ordered == 6)
        #expect(placed == 6)

        let habits = try context.fetch(FetchDescriptor<Habit>())
        #expect(habits.count == 6)
        // `title` defaults to `""`, `category` to `.unlabeled`, `graceDays` to
        // 2, `frequencyRawValues` to `[]`. None of those may be what reads
        // back.
        let named = habits.filter { !$0.title.isEmpty }.count
        let categorised = habits.filter { $0.category != .unlabeled }.count
        let scheduled = habits.filter { $0.frequencyRawValues == ["Mo", "We", "Fr"] }.count
        let towered = habits.filter { $0.tower?.name == "Home" }.count
        let filed = habits.filter { $0.planFolder?.name == "Errands" }.count
        #expect(named == 6)
        #expect(categorised == 6)
        #expect(habits.map(\.graceDays).sorted() == [0, 1, 2, 3, 4, 5])
        #expect(scheduled == 6)
        #expect(towered == 6)
        #expect(filed == 6)

        let towers = try context.fetch(FetchDescriptor<Tower>())
        #expect(towers.first?.name == "Home")
        #expect(towers.first?.emoji == "🧱")
        #expect(towers.first?.order == 3)

        let folders = try context.fetch(FetchDescriptor<PlanFolder>())
        #expect(folders.first?.icon == "bag.fill")
        #expect(folders.first?.colorHex == "#FF8800")
        #expect(folders.first?.sortOrder == 2)

        let moods = try context.fetch(FetchDescriptor<MoodLog>())
        // The defaults are 3 and 3.
        #expect(moods.first?.mood == 5)
        #expect(moods.first?.motivation == 2)

        let items = try context.fetch(FetchDescriptor<PlanItem>())
        #expect(items.first?.text == "Call the landlord")
        #expect(items.first?.repeatDaysRaw == "2,4")
    }

    @Test("the digest notices a single changed value")
    func digestCanFail() throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let context = ModelContext(try container(at: url))
        try seedEverything(context)
        let before = StoreRecordDigest.read(context: context)

        let log = try #require(try context.fetch(FetchDescriptor<HabitLog>()).first)
        log.caption = "something else"
        try context.save()

        #expect(StoreRecordDigest.read(context: context).digest != before.digest)
    }

    /// The three `createdAt`s were missing from the reading, so any of them
    /// could have been flattened to launch time with the check still passing.
    @Test("flattening any defaulted createdAt to now changes the digest", arguments: ["habit", "tower", "folder"])
    func createdAtIsRead(which: String) throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let context = ModelContext(try container(at: url))
        try seedEverything(context)
        let past = Date(timeIntervalSinceReferenceDate: 700_000_000)
        for habit in try context.fetch(FetchDescriptor<Habit>()) { habit.createdAt = past }
        for tower in try context.fetch(FetchDescriptor<Tower>()) { tower.createdAt = past }
        for folder in try context.fetch(FetchDescriptor<PlanFolder>()) { folder.createdAt = past }
        try context.save()
        let before = StoreRecordDigest.read(context: context)

        switch which {
        case "habit": try context.fetch(FetchDescriptor<Habit>()).first?.createdAt = Date()
        case "tower": try context.fetch(FetchDescriptor<Tower>()).first?.createdAt = Date()
        default: try context.fetch(FetchDescriptor<PlanFolder>()).first?.createdAt = Date()
        }
        try context.save()

        #expect(StoreRecordDigest.read(context: context).digest != before.digest)
    }

    @Test("moving a habit to another tower with the same name changes the digest")
    func towerIsReadByID() throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let context = ModelContext(try container(at: url))
        try seedEverything(context)
        let before = StoreRecordDigest.read(context: context)

        let twin = Tower(name: "Home", emoji: "🧱", order: 3)
        context.insert(twin)
        let habit = try #require(try context.fetch(FetchDescriptor<Habit>()).first)
        habit.tower = twin
        try context.save()
        let after = StoreRecordDigest.read(context: context)

        // The twin is a new row, so the counts move too; the habit line is
        // what this pins, by removing the twin row's own line from the reading.
        let habitLine = { (r: StoreRecordDigest.Reading) in
            r.body.split(separator: "\n").first { $0.hasPrefix(habit.id.uuidString) }.map(String.init)
        }
        #expect(habitLine(after) != habitLine(before))
    }

    @Test("the digest is the same number in a second process, not a seeded hash")
    func digestIsStable() {
        // `hashValue` is seeded per process, so a digest built on it would
        // differ between the old build's launch and the new one whether or not
        // anything had changed. This is the pin on that.
        #expect(StableDigest.of("a win|2026-09-01|true") == "4754f54761898014")
        #expect(StableDigest.of("") == "cbf29ce484222325")
    }
}
