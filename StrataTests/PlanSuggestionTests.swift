import Testing
import Foundation
@testable import Strata

/// The rules every suggestion is cleaned to, whatever the model says.
@Suite("Plan suggestions")
struct PlanSuggestionTests {
    func s(_ title: String, _ category: HabitCategory = .health, _ size: BlockSize = .small,
           _ days: Set<Int> = []) -> PlanSuggestion {
        PlanSuggestion(title: title, category: category, size: size, repeatDays: days)
    }

    var saturday: PlanSuggestionContext {
        PlanSuggestionContext(today: 7, weekday: "Saturday", partOfDay: "morning", planLines: ["Walk the dog"],
                              recentByCategory: [:], frequentTitles: [], alreadyShown: ["Read"])
    }

    @Test func atMostThreeAndNeverWhatIsAlreadyThere() {
        let out = PlanSuggestionRules.clean([
            s("Walk the dog"), s("read"), s("Stretch", .mindfulness), s("Call mum", .social),
            s("Sketch", .creativity), s("Plan week", .work),
        ], context: saturday)
        #expect(out.map(\.title) == ["Stretch", "Call mum", "Sketch"])
    }

    @Test func titlesAreShortPlainAndCapitalised() {
        #expect(PlanSuggestionRules.tidy("go for a long walk outside today.") == "Go for a long")
        #expect(PlanSuggestionRules.tidy("drink water 💧!") == "Drink water")
        #expect(PlanSuggestionRules.tidy("   ") == "")
    }

    @Test func onlyOneLargeBlock() {
        let out = PlanSuggestionRules.clean([
            s("Deep work", .work, .hard), s("Long run", .health, .hard), s("Paint", .creativity, .hard),
        ], context: saturday)
        #expect(out.filter { $0.size == .hard }.count == 1)
        #expect(out.filter { $0.size == .medium }.count == 2)
    }

    @Test func aRoutineReadsInTwoWords() {
        func days(_ given: Set<Int>) -> Set<Int>? {
            PlanSuggestionRules.clean([s("Stretch", .mindfulness, .small, given)], context: saturday).first?.repeatDays
        }
        // Saturday: a routine is every day or weekends, never a list of days.
        #expect(days([2, 3, 4, 5, 6]) == Set(1...7))
        #expect(days([2, 4]) == [1, 7])
        #expect(days([1, 7]) == [1, 7])
        #expect(days([0, 9]) == [])
        #expect(PlanSuggestionRules.snap([3], today: 4) == Set(2...6))
    }

    @Test func threeDifferentCategoriesLeastDoneFirst() {
        var context = saturday
        context.recentByCategory = [.health: 9, .work: 4]
        let out = PlanSuggestionRules.clean([
            s("Run", .health), s("Journal", .mindfulness), s("Meditate", .mindfulness),
            s("Inbox", .work), s("Call", .social),
        ], context: context)
        #expect(out.map(\.title) == ["Journal", "Call", "Inbox"])
    }

    @Test func onlyOneRoutine() {
        let out = PlanSuggestionRules.clean([
            s("Journal", .mindfulness, .small, Set(1...7)), s("Run", .health, .small, Set(1...7)),
            s("Call", .social, .small, [7]),
        ], context: saturday)
        #expect(out.filter { !$0.repeatDays.isEmpty }.count == 1)
    }

    @Test func anObviousWordFixesTheColour() {
        let out = PlanSuggestionRules.clean([s("Walk ten minutes", .focus)], context: saturday)
        #expect(out.first?.category == .health)
        #expect(PlanSuggestionRules.obviousCategory("Write in a journal") == .mindfulness)
        #expect(PlanSuggestionRules.obviousCategory("Read to your mum") == nil)
        #expect(PlanSuggestionRules.obviousCategory("Water the plants") == nil)
        #expect(PlanSuggestionRules.obviousCategory("Drink water") == .health)
    }

    @Test func unlabeledIsNeverSuggested() {
        #expect(PlanSuggestionRules.clean([s("Thing", .unlabeled)], context: saturday).isEmpty)
    }

    @Test func theContextCountsTheLastTwoWeeksAndFindsRoutines() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        var wins: [(title: String, category: HabitCategory, date: Date)] = []
        for day in 0..<5 {
            wins.append(("Gym", .health, calendar.date(byAdding: .day, value: -day, to: now)!))
        }
        wins.append(("Old", .work, calendar.date(byAdding: .day, value: -30, to: now)!))
        let context = PlanSuggestionContext.make(plan: ["", "Walk"], wins: wins, now: now, calendar: calendar)
        #expect(context.recentByCategory == [.health: 5])
        #expect(context.frequentTitles == ["Gym"])
        #expect(context.planLines == ["Walk"])
        #expect(context.prompt.contains("Gym"))
        #expect(!context.prompt.contains("Old"))
    }

    @Test func theFixedSuggesterFollowsTheRules() async throws {
        let out = try await FixedPlanSuggester().suggest(saturday)
        #expect(out.count == 3)
        #expect(Set(out.map(\.category)).count == 3)
    }
}
