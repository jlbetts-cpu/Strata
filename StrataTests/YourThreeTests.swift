import Testing
import Foundation
@testable import Strata

/// **Your three** (the owner, 2026-10-06: "add people's 3 daily minimums ...
/// wins that no matter what life does ... you can adhere to"; asked in
/// onboarding after the goal, skippable). The Hard day switch that came with
/// them is gone (2026-10-07, his pick).
@MainActor
@Suite("Your three")
struct YourThreeTests {
    typealias Item = YourThree.Item
    typealias L = WinIdeas.Logged
    let today = "2026-10-06"

    @Test("the three survive a round trip, trimmed, each once, three at most")
    func storage() {
        let items = [Item(title: "Drank some water", category: .health),
                     Item(title: "  Fed the cat ", category: nil),
                     Item(title: "drank some water", category: .health),
                     Item(title: "", category: .work),
                     Item(title: "Went outside", category: .health),
                     Item(title: "Took my meds", category: .health)]
        let back = YourThree.decode(YourThree.encode(items))
        #expect(back.map(\.title) == ["Drank some water", "Fed the cat", "Went outside"])
        #expect(back[0].category == .health && back[1].category == nil)
        #expect(YourThree.decode("").isEmpty)
        #expect(YourThree.decode("not json").isEmpty, "unreadable is no list, never a crash")
        #expect(YourThree.encode([]) == "[]" && YourThree.decode("[]").isEmpty)
    }

    @Test("they lead the ideas row, and one logged today drops out as any idea does")
    func ideasLead() {
        let three = [Item(title: "Drank some water", category: .health),
                     Item(title: "Fed the cat", category: nil),
                     Item(title: "Went outside", category: .health)]
        let plan = [WinIdea(title: "Call the landlord", category: .social)]
        let logged = [L(title: "drank some water", category: .health, day: today),
                      L(title: "Fed the cat", category: .creativity, day: "2026-10-03")]
        let ideas = WinIdeas.pick(three: YourThree.ideas(three, logged: logged), plan: plan,
                                  logged: logged, today: today)
        #expect(ideas.prefix(3).map(\.title) == ["Fed the cat", "Went outside", "Call the landlord"])
        #expect(!ideas.contains { $0.id == "drank some water" }, "done today, matched by title")
        #expect(ideas.count == WinIdeas.limit)
        // Typing narrows them as it narrows every idea.
        #expect(WinIdeas.pick(three: YourThree.ideas(three, logged: []), plan: [], logged: [], today: today,
                              typed: "fed").map(\.title) == ["Fed the cat"])
    }

    @Test("a typed one takes the colour it was last logged in, else keeps the sheet's")
    func typedColour() {
        let mine = [Item(title: "Fed the cat", category: nil)]
        let never = YourThree.ideas(mine, logged: [])
        #expect(never.first?.keepsColour == true)
        let logged = [L(title: "Fed the cat", category: .social, day: "2026-10-01"),
                      L(title: "fed the cat", category: .creativity, day: "2026-10-04")]
        let seen = YourThree.ideas(mine, logged: logged)
        #expect(seen.first?.category == .creativity && seen.first?.keepsColour == false)
        // A pick carries its own colour.
        #expect(YourThree.ideas([YourThree.picks[0]], logged: []).first?.category == YourThree.picks[0].category)
    }

    @Test("a tick only for what is logged today, matched as the ideas match")
    func done() {
        let three = [Item(title: "Drank some water", category: .health),
                     Item(title: "Went outside", category: .health)]
        #expect(YourThree.done(three, titlesToday: [" drank some WATER ", "Walk"]) == ["drank some water"])
        #expect(YourThree.done(three, titlesToday: []).isEmpty)
    }

    @Test("today's goal is the goal you set: there is no Hard day")
    func noHardDay() {
        let defaults = UserDefaults(suiteName: "YourThreeTests.\(UUID())")!
        #expect(DailyGoal.stored(on: today, defaults: defaults) == DailyGoal.standard)
        defaults.set(8, forKey: DailyGoal.defaultsKey)
        #expect(DailyGoal.stored(on: today, defaults: defaults) == 8)
    }

    @Test("the words: no long dash, and nothing that counts against you")
    func copy() {
        let banned = ["missed", "streak", "don't break", "don\u{2019}t break", "non-negotiable", "minimum"]
        let words = YourThree.Copy.all + YourThree.picks.map(\.title)
        for line in words {
            #expect(!SourceSweep.longDash(line), "\(line)")
            for word in banned { #expect(!line.lowercased().contains(word), "\(line) says \(word)") }
        }
        #expect(YourThree.Copy.pickerTitle == "Three for any day")
        #expect(YourThree.Copy.footer == "Small enough for your hardest day. Any of them counts.")
        #expect(YourThree.picks.map(\.title) == ["Drank some water", "Went outside", "Replied to a message",
                                                 "Took my meds", "Ate a real meal", "Brushed my teeth",
                                                 "Opened a window", "Stretched for a minute"])
    }

    @Test("onboarding asks after the goal, ticks nothing, and can be skipped")
    func onboarding() throws {
        let view = SourceSweep.code(try SourceSweep.read("Strata/Views/OnboardingView.swift"))
        #expect(view.contains("private static let goalStep = 6"))
        #expect(view.contains("private static let threeStep = 7"))
        #expect(view.contains("private static let firstWinStep = 8"))
        #expect(view.contains("@State private var threePicked: [YourThree.Item] = []"), "nothing pre-ticked")
        #expect(view.contains("if step == Self.threeStep { decline(YourThree.Copy.onboardingSkip) }"))
    }

    @Test("Wins asks today's goal everywhere: crest, cue, dance, booth")
    func wired() throws {
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("goal: todaysGoal)"), "the cue")
        #expect(main.contains("DailyGoal.reached(from: old, to: new, goal: todaysGoal)"), "the booth opens")
        #expect(main.contains("canDevelop: { blocksToday >= todaysGoal }"))
        #expect(!main.contains(">= dailyGoal"), "nothing on Wins reads the set number as today's")
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/YourDaySheet.swift"))
        #expect(sheet.contains("yourThree"))
        #expect(!sheet.contains("circle\")"), "not done is only its words, never an empty circle")
        let ideas = SourceSweep.code(try SourceSweep.read("Strata/Services/WinIdeas.swift"))
        #expect(ideas.contains("for idea in three + plan + usual + smalls"))
    }

    @Test("pinned at the top of every day's plan, ticked from today's wins, never stored per day")
    func inThePlan() throws {
        let lines = SourceSweep.code(try SourceSweep.read("Strata/Views/PlanLines.swift"))
        #expect(lines.contains("if onThree != nil { yourThree }"), "above the day's own lines")
        #expect(lines.contains("YourThree.done(three, titlesToday: WinIdeas.titlesToday(context: modelContext))"),
                "the tick is today's wins, so midnight resets it with no sweep")
        #expect(!lines.contains("PlanItem(text: item.title"), "never written into the plan as lines")
        let day = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(day.contains("onThree: onThree)"))
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.contains("pendingDraft = WinDraft(title: three.title, size: .small, colour: colour)"),
                "a press opens Add with it written, as a plan line does")
    }
}
