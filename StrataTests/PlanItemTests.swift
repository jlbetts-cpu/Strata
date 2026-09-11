import Foundation
import SwiftData
import Testing

@testable import Strata

/// **A tick on the plan must never outlive the block it stands for.**
///
/// Reported from a phone: "you can make a point and then drop it and then
/// remove it and its still checked off in the plan screen." Two separate
/// paths left a finished line behind — cancelling the add sheet, and deleting
/// the win afterwards — and in both the plan went on claiming something the
/// tower no longer supported.
///
/// These use an in-memory container, which is a new shape for this suite:
/// everything else here is a pure function over value types, on purpose. The
/// rule being protected is about stored state, so there is nothing to test
/// without a store.
@MainActor
struct PlanItemTests {

    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: PlanItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test("unticking a line clears its completion")
    func untickClearsCompletion() throws {
        let context = try context()
        let item = PlanItem(text: "Walk", order: 0, category: .health)
        item.completedAt = Date()
        context.insert(item)
        try context.save()
        #expect(item.isDone)

        PlanItem.untick(planItemID: item.id, context: context)
        #expect(!item.isDone, "deleting the block should have put the line back")
    }

    @Test("unticking an unknown id changes nothing and does not crash")
    func untickIgnoresStrangers() throws {
        let context = try context()
        let item = PlanItem(text: "Walk", order: 0, category: .health)
        item.completedAt = Date()
        context.insert(item)
        try context.save()

        PlanItem.untick(planItemID: UUID(), context: context)
        #expect(item.isDone, "a different line must not be touched")
    }

    @Test("unticking nothing is a no-op")
    func untickIgnoresNil() throws {
        let context = try context()
        let item = PlanItem(text: "Walk", order: 0, category: .health)
        item.completedAt = Date()
        context.insert(item)
        try context.save()

        // A win that never came from a plan carries a nil id, and every
        // deletion path calls this unconditionally.
        PlanItem.untick(planItemID: nil, context: context)
        #expect(item.isDone)
    }
}
