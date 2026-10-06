import Foundation
import SwiftData

/// **Deleting a win, with a few seconds to take it back** (the owner,
/// 2026-10-06, replacing the "Delete this?" dialog).
///
/// A confirm in front of every delete is a step people learn to press through
/// (NN/g, "Confirmation Dialogs Can Prevent User Errors, If Not Overused"),
/// and it still let a photographed win go for good. So the rows go at once,
/// a plain copy of them is kept, and the photographs stay on disk until the
/// undo line has gone: `undo` puts the win and its logs back from the copy,
/// with the same ids, and ticks its plan line again; `finish` is when the
/// files go.
///
/// **A copy, not `ModelContext.undoManager`.** That was tried first and
/// measured: SwiftData recorded the deletion (`canUndo` true) and undoing it
/// brought nothing back once the deletion had been saved.
@MainActor
enum WinDeletion {
    struct Pending {
        let undo: () -> Void
        let finish: () -> Void
    }

    static func delete(_ habit: Habit, in context: ModelContext) throws -> Pending {
        let copy = WinCopy(habit)
        // Read before the rows go, or there is nothing left to read them from.
        let names = copy.logs.compactMap(\.imageFileName)
        do {
            try context.transaction {
                for log in habit.logs ?? [] { context.delete(log) }
                PlanItem.untick(planItemID: habit.planItemID, context: context)
                context.delete(habit)
            }
        } catch {
            context.rollback()
            throw error
        }
        return Pending(
            undo: {
                copy.restore(in: context)
                try? context.save()
            },
            finish: {
                for name in names { ImageManager.shared.deleteImage(fileName: name) }
            }
        )
    }
}

/// Everything a win and its logs hold, as plain values. Deprecated fields the
/// models keep only for the schema are left behind.
@MainActor
private struct WinCopy {
    struct Log {
        let id: UUID, dateString: String, completed: Bool, completedAt: Date?
        let note: String?, caption: String, imageFileName: String?
        let cropX: Double?, cropY: Double?, surgeMode: Bool, pendingXP: Int?, xpCollected: Bool
        let isBonusBlock: Bool, skipped: Bool, verifiedByHealthKit: Bool, subtasks: [SubTask]
        let towerOrder: Int?, latitude: Double?, longitude: Double?, locationAccuracy: Double?
        let createdAt: Date, updatedAt: Date, timeZoneIdentifier: String
    }

    let id: UUID, title: String, category: HabitCategory, blockSize: BlockSize
    let frequencyRawValues: [String], createdAt: Date, updatedAt: Date
    let scheduledTime: String?, reminderEnabled: Bool, isTodo: Bool, scheduledDate: String?
    let todoOrder: Int?, creationXP: Int, graceDays: Int, timeOfDay: TimeOfDay?
    let anchorHabitID: UUID?, planItemID: UUID?, parentHabitID: UUID?, sortOrder: Int
    let isStepCompleted: Bool, isInProgress: Bool, isSaved: Bool, isQuickWin: Bool
    let spontaneousCategoryRaw: String?, healthKitType: String?, healthKitThreshold: Double?
    let customDurationMinutes: Int?, tower: Tower?, planFolder: PlanFolder?
    let logs: [Log]

    init(_ h: Habit) {
        id = h.id; title = h.title; category = h.category; blockSize = h.blockSize
        frequencyRawValues = h.frequencyRawValues; createdAt = h.createdAt; updatedAt = h.updatedAt
        scheduledTime = h.scheduledTime; reminderEnabled = h.reminderEnabled; isTodo = h.isTodo
        scheduledDate = h.scheduledDate; todoOrder = h.todoOrder; creationXP = h.creationXP
        graceDays = h.graceDays; timeOfDay = h.timeOfDay; anchorHabitID = h.anchorHabitID
        planItemID = h.planItemID; parentHabitID = h.parentHabitID; sortOrder = h.sortOrder
        isStepCompleted = h.isStepCompleted; isInProgress = h.isInProgress; isSaved = h.isSaved
        isQuickWin = h.isQuickWin; spontaneousCategoryRaw = h.spontaneousCategoryRaw
        healthKitType = h.healthKitType; healthKitThreshold = h.healthKitThreshold
        customDurationMinutes = h.customDurationMinutes; tower = h.tower; planFolder = h.planFolder
        logs = (h.logs ?? []).map { l in
            Log(id: l.id, dateString: l.dateString, completed: l.completed, completedAt: l.completedAt,
                note: l.note, caption: l.caption, imageFileName: l.imageFileName,
                cropX: l.cropPositionX, cropY: l.cropPositionY, surgeMode: l.surgeMode,
                pendingXP: l.pendingXP, xpCollected: l.xpCollected, isBonusBlock: l.isBonusBlock,
                skipped: l.skipped, verifiedByHealthKit: l.verifiedByHealthKit, subtasks: l.subtasks,
                towerOrder: l.towerOrder, latitude: l.latitude, longitude: l.longitude,
                locationAccuracy: l.locationAccuracy, createdAt: l.createdAt, updatedAt: l.updatedAt,
                timeZoneIdentifier: l.timeZoneIdentifier)
        }
    }

    func restore(in context: ModelContext) {
        let h = Habit(title: title, category: category, blockSize: blockSize)
        h.id = id; h.frequencyRawValues = frequencyRawValues; h.createdAt = createdAt
        h.scheduledTime = scheduledTime; h.reminderEnabled = reminderEnabled; h.isTodo = isTodo
        h.scheduledDate = scheduledDate; h.todoOrder = todoOrder; h.creationXP = creationXP
        h.graceDays = graceDays; h.timeOfDay = timeOfDay; h.anchorHabitID = anchorHabitID
        h.planItemID = planItemID; h.parentHabitID = parentHabitID; h.sortOrder = sortOrder
        h.isStepCompleted = isStepCompleted; h.isInProgress = isInProgress; h.isSaved = isSaved
        h.isQuickWin = isQuickWin; h.spontaneousCategoryRaw = spontaneousCategoryRaw
        h.healthKitType = healthKitType; h.healthKitThreshold = healthKitThreshold
        h.customDurationMinutes = customDurationMinutes
        context.insert(h)
        h.tower = tower
        h.planFolder = planFolder
        for c in logs {
            let l = HabitLog(habit: h, dateString: c.dateString, completed: c.completed)
            l.id = c.id; l.completedAt = c.completedAt; l.note = c.note; l.caption = c.caption
            l.imageFileName = c.imageFileName; l.cropPositionX = c.cropX; l.cropPositionY = c.cropY
            l.surgeMode = c.surgeMode; l.pendingXP = c.pendingXP; l.xpCollected = c.xpCollected
            l.isBonusBlock = c.isBonusBlock; l.skipped = c.skipped
            l.verifiedByHealthKit = c.verifiedByHealthKit; l.subtasks = c.subtasks
            l.towerOrder = c.towerOrder; l.latitude = c.latitude; l.longitude = c.longitude
            l.locationAccuracy = c.locationAccuracy; l.createdAt = c.createdAt
            l.timeZoneIdentifier = c.timeZoneIdentifier
            context.insert(l)
            l.updatedAt = c.updatedAt
        }
        h.updatedAt = updatedAt
        // The line this win came from is done again.
        if let planItemID {
            let descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate { $0.id == planItemID })
            if let line = try? context.fetch(descriptor).first, line.completedAt == nil {
                line.completedAt = logs.first?.completedAt ?? createdAt
            }
        }
    }
}
