import Testing
import Foundation
import SwiftData
@testable import Strata

/// **Wins to tap, not to remember** (2026-10-06, testers logging one or two a
/// day): the row over the add sheet's keyboard.
@MainActor
@Suite("Win ideas")
struct WinIdeasTests {
    typealias L = WinIdeas.Logged
    let today = "2026-10-06"

    @Test("the plan comes first, then what you log most days, then small ones")
    func order() {
        let plan = [WinIdea(title: "Call the landlord", category: .social)]
        let logged = [L(title: "Walk", category: .health, day: "2026-10-01"),
                      L(title: "Walk", category: .health, day: "2026-10-03"),
                      L(title: "Walk", category: .health, day: "2026-10-04"),
                      L(title: "Read", category: .creativity, day: "2026-10-02"),
                      L(title: "Read", category: .creativity, day: "2026-10-05"),
                      L(title: "Once", category: .work, day: "2026-10-02")]
        let ideas = WinIdeas.pick(plan: plan, logged: logged, today: today)
        #expect(ideas.prefix(3).map(\.title) == ["Call the landlord", "Walk", "Read"])
        #expect(!ideas.contains { $0.title == "Once" }, "one day is not a usual")
        #expect(ideas.count == WinIdeas.limit)
        #expect(ideas.dropFirst(3).allSatisfy { idea in WinIdeas.small.contains(idea) })
    }

    @Test("what is already on today's tower is never offered again, in any case")
    func notTwice() {
        let logged = [L(title: "Walk", category: .health, day: "2026-10-01"),
                      L(title: "Walk", category: .health, day: "2026-10-02"),
                      L(title: "walk", category: .health, day: today),
                      L(title: "Made my bed", category: .mindfulness, day: today)]
        let ideas = WinIdeas.pick(plan: [WinIdea(title: "Walk", category: .health)], logged: logged, today: today)
        #expect(!ideas.contains { $0.id == "walk" })
        #expect(!ideas.contains { $0.id == "made my bed" })
    }

    @Test("typing narrows the row to words that start that way, and the exact name drops out")
    func narrows() {
        let logged = [L(title: "Morning walk", category: .health, day: "2026-10-01"),
                      L(title: "Morning walk", category: .health, day: "2026-10-02")]
        #expect(WinIdeas.pick(plan: [], logged: logged, today: today, typed: "wal").map(\.title) == ["Morning walk"])
        #expect(WinIdeas.pick(plan: [], logged: logged, today: today, typed: "morn").first?.title == "Morning walk")
        #expect(WinIdeas.pick(plan: [], logged: logged, today: today, typed: "Morning walk").isEmpty)
        #expect(WinIdeas.pick(plan: [], logged: logged, today: today, typed: "zzz").isEmpty)
    }

    @Test("a one-tap win's placeholder name is never an idea")
    func noPlaceholder() {
        let logged = [L(title: QuickWinService.untitled, category: .health, day: "2026-10-01"),
                      L(title: QuickWinService.untitled, category: .health, day: "2026-10-02")]
        #expect(!WinIdeas.pick(plan: [], logged: logged, today: today).contains { $0.title == QuickWinService.untitled })
    }

    @Test("the small ones turn with the day")
    func turns() {
        let a = WinIdeas.pick(plan: [], logged: [], today: "2026-10-06").first
        let days = (1...9).map { String(format: "2026-10-%02d", $0) }
        #expect(Set(days.compactMap { WinIdeas.pick(plan: [], logged: [], today: $0).first?.title }).count > 1)
        #expect(a != nil)
    }

    @Test("a plan line logged by name is ticked on the plan, once")
    func ticks() throws {
        let container = try ModelContainer(for: SharedModelContainer.schema,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let line = PlanItem(text: "Call the landlord", order: 0)
        context.insert(line)
        WinIdeas.tickPlanLine(named: "call the landlord", context: context)
        #expect(line.completedAt != nil)
    }

    @Test("the add sheet carries the row over its keyboard, and ticks the plan on save")
    func wired() throws {
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        #expect(sheet.contains("ToolbarItemGroup(placement: .keyboard)"))
        #expect(sheet.contains("WinIdeas.tickPlanLine(named: title, context: modelContext)"))
    }
}
