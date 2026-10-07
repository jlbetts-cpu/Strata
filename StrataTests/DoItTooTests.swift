import Testing
import Foundation
import SwiftData
@testable import Strata

/// **Do It Too** (2026-10-06, the retention pass): a friend's win on your own
/// plan, in its colour and size, from the photo viewer's menu.
@MainActor
@Suite("Do It Too")
struct DoItTooTests {
    func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return ModelContext(container)
    }

    @Test("a friend's win lands at the end of your plan, in its colour and size")
    func lands() throws {
        let context = try context()
        context.insert(PlanItem(text: "Laundry", order: 3))
        let line = try #require(DayComposing.doItToo(" Morning walk ", colour: .health, size: .hard, context: context))
        #expect(line.text == "Morning walk")
        #expect(line.order == 4)
        #expect(line.category == .health)
        #expect(line.sizeRaw == BlockSize.hard.rawValue)
    }

    @Test("the same win twice is one line, until it is done")
    func once() throws {
        let context = try context()
        let first = DayComposing.doItToo("Gym", colour: .health, size: .small, context: context)
        let again = DayComposing.doItToo("gym", colour: .work, size: .small, context: context)
        #expect(first?.id == again?.id)
        #expect(try context.fetch(FetchDescriptor<PlanItem>()).count == 1)
        first?.completedAt = .now
        #expect(DayComposing.doItToo("Gym", colour: .health, size: .small, context: context)?.id != first?.id)
    }

    @Test("an unnamed win has nothing to plan")
    func unnamed() throws {
        #expect(DayComposing.doItToo("  ", colour: .health, size: .small, context: try context()) == nil)
    }

    @Test("the viewer offers it on a friend's named win, and a crew win carries its colour")
    func wired() throws {
        let viewer = SourceSweep.code(try SourceSweep.read("Strata/Views/PhotoViewer.swift"))
        #expect(viewer.contains("Label(done ? \"On Your Plan\" : \"Do It Too\""))
        let gallery = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewDayView.swift"))
        #expect(gallery.contains("colour: win.colour)"))
    }
}
