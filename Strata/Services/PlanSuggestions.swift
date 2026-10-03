import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// **A few plan lines for someone who doesn't know what to do today.**
///
/// The owner, 2026-10-03: "a super simple ai but it prioritizes research first
/// and talks very simply and minimally... just for helping them formulate a
/// plan", and then "really minimal and clean... not a crazy amount of
/// information at once". So it is not a chat. Suggest gives three lines, each
/// a box to check, and checking one makes it a real plan line.
///
/// **The research it follows** (`docs/superpowers/specs/2026-10-03-plan-suggestions-design.md`):
/// small actions anchored to a routine you already have form habits most
/// reliably (Fogg, Tiny Habits; implementation intentions roughly double
/// follow-through, Gollwitzer); a balanced day touches several parts of life;
/// and a few options beat many. Apple's model runs on the phone, so nothing
/// here leaves it.
nonisolated struct PlanSuggestion: Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var category: HabitCategory
    var size: BlockSize
    /// 1 = Sunday through 7 = Saturday, as `PlanItem` keeps them. Empty: once.
    var repeatDays: Set<Int>
}

/// What the model is told about today. All of it is on the phone already.
nonisolated struct PlanSuggestionContext: Equatable, Sendable {
    /// Today, 1 = Sunday through 7 = Saturday.
    var today: Int = 1
    var weekday: String
    var partOfDay: String
    /// Lines already on the plan, never suggested again.
    var planLines: [String]
    /// Wins in each category over the last two weeks: the gaps are where a
    /// balanced day goes.
    var recentByCategory: [HabitCategory: Int]
    /// Wins logged on four or more of the last fourteen days: worth a repeat.
    var frequentTitles: [String]
    /// What was suggested before this ask, so Others brings others.
    var alreadyShown: [String]

    static func make(plan: [String], wins: [(title: String, category: HabitCategory, date: Date)],
                     alreadyShown: [String] = [], now: Date = Date(),
                     calendar: Calendar = .current) -> PlanSuggestionContext {
        let since = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let recent = wins.filter { $0.date >= since && $0.date <= now }
        var byCategory: [HabitCategory: Int] = [:]
        for win in recent where win.category != .unlabeled { byCategory[win.category, default: 0] += 1 }
        var days: [String: Set<Date>] = [:]
        var spelling: [String: String] = [:]
        for win in recent {
            let key = win.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            days[key, default: []].insert(calendar.startOfDay(for: win.date))
            spelling[key] = spelling[key] ?? win.title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let frequent = days.filter { $0.value.count >= 4 }.keys.sorted().compactMap { spelling[$0] }
        let hour = calendar.component(.hour, from: now)
        let part = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
        let weekday = calendar.weekdaySymbols[calendar.component(.weekday, from: now) - 1]
        return PlanSuggestionContext(today: calendar.component(.weekday, from: now),
                                     weekday: weekday, partOfDay: part,
                                     planLines: plan.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                                     recentByCategory: byCategory, frequentTitles: frequent,
                                     alreadyShown: alreadyShown)
    }

    /// The prompt, in plain lines.
    var prompt: String {
        var lines = ["It is \(weekday) \(partOfDay)."]
        let counts = HabitCategory.selectable.map { "\($0.rawValue) \(recentByCategory[$0] ?? 0)" }
        lines.append("Wins in the last two weeks by category: \(counts.joined(separator: ", ")).")
        if !frequentTitles.isEmpty {
            lines.append("Things they already do often: \(frequentTitles.prefix(5).joined(separator: ", ")).")
        }
        if !planLines.isEmpty {
            lines.append("Already on today's plan, do not repeat: \(planLines.prefix(12).joined(separator: ", ")).")
        }
        if !alreadyShown.isEmpty {
            lines.append("Already suggested, give different ones: \(alreadyShown.joined(separator: ", ")).")
        }
        lines.append("Suggest a balanced plan.")
        return lines.joined(separator: "\n")
    }
}

/// **Whatever the model says, cleaned to what the plan can hold.** A small
/// model drifts; these are the rules, kept in code where they can be tested.
nonisolated enum PlanSuggestionRules {
    /// Three: the owner asked for little at once, and few options beat many.
    static let count = 3
    static let maxWords = 4

    static let instructions = """
        You help someone plan a simple, balanced day. You only suggest plan lines.
        Each line is something small and concrete they can do today.
        Rules:
        - Suggest exactly five varied lines across different parts of life.
        - Prefer the categories they have done least lately.
        - Give each line its true category:
          health is the body: movement, sleep, food, water.
          work is jobs, school, chores, errands, admin.
          creativity is making things: art, music, writing, cooking for fun.
          focus is the mind: reading, studying, learning, planning.
          social is people: friends, family, calls, messages.
          mindfulness is calm: meditation, breathing, journaling, rest.
        - Titles are specific and small, two to four plain words, starting with
          a verb, with an amount or a moment: "Walk ten minutes", "Text a
          friend", "Stretch after coffee". No emoji.
        - Fit what is left of the day: nothing for the morning in the evening.
        - Most lines are small (under 15 minutes). At most one is large.
        - At most one line repeats: a routine worth keeping. If they already
          do something often, that is the routine, in their own words. Give
          it the weekdays it repeats on. Every other line is just for today,
          with no weekdays.
        - Where it fits in four words, tie a repeat to a routine, like
          "Stretch after coffee".
        - Never repeat anything already on their plan.
        """

    /// The model is asked for more than are shown (`asked`), so the three
    /// kept can each be a different part of life, the least done first. A
    /// small model asked for three different categories gave two the same.
    static let asked = 5

    static func clean(_ raw: [PlanSuggestion], context: PlanSuggestionContext) -> [PlanSuggestion] {
        var seen = Set((context.planLines + context.alreadyShown).map(key))
        // Least done lately first, keeping the model's order otherwise.
        let ranked = raw.enumerated().sorted {
            let a = context.recentByCategory[$0.element.category] ?? 0
            let b = context.recentByCategory[$1.element.category] ?? 0
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
        // One per category when there are enough categories to go round.
        let varied = Set(raw.map(\.category)).subtracting([.unlabeled]).count >= count
        var categories: Set<HabitCategory> = []
        var out: [PlanSuggestion] = []
        var hasLarge = false
        var hasRepeat = false
        for var suggestion in ranked {
            suggestion.title = tidy(suggestion.title)
            let k = key(suggestion.title)
            guard !suggestion.title.isEmpty, !seen.contains(k) else { continue }
            if let plain = obviousCategory(suggestion.title) { suggestion.category = plain }
            if suggestion.category == .unlabeled { continue }
            if varied, categories.contains(suggestion.category) { continue }
            if suggestion.size == .hard {
                if hasLarge { suggestion.size = .medium } else { hasLarge = true }
            }
            // One routine at a time: a plan of repeats is a schedule, and
            // the research says start with one small habit.
            if !suggestion.repeatDays.isEmpty {
                if hasRepeat { suggestion.repeatDays = [] } else { hasRepeat = true }
            }
            suggestion.repeatDays = snap(suggestion.repeatDays.filter { (1...7).contains($0) },
                                         today: context.today)
            seen.insert(k)
            categories.insert(suggestion.category)
            out.append(suggestion)
            if out.count == count { break }
        }
        return out
    }

    /// **A safety net for the colour.** The model once called "Walk" focus,
    /// and the colour is half of what a suggestion says. When the title
    /// holds a word that belongs to exactly one category, that category
    /// wins; a title that matches two ("Write in a journal") or none keeps
    /// the model's choice.
    static let plainWords: [HabitCategory: Set<String>] = [
        .health: ["walk", "run", "jog", "gym", "yoga", "stretch", "swim", "bike", "cycle", "workout",
                  "exercise", "sleep", "nap", "eat", "drink", "vegetables", "fruit", "steps", "lift"],
        .work: ["email", "emails", "inbox", "laundry", "dishes", "clean", "tidy", "bills", "errand",
                "errands", "homework", "chores", "groceries", "budget", "invoice"],
        .creativity: ["draw", "sketch", "paint", "piano", "guitar", "sing", "song", "photo", "photograph",
                      "craft", "knit", "bake", "doodle", "poem"],
        .focus: ["read", "study", "learn", "chapter", "course", "practice", "review", "plan", "research"],
        .social: ["call", "text", "friend", "friends", "family", "mom", "mum", "dad", "visit", "message",
                  "neighbor", "neighbour", "partner", "grandma", "grandpa"],
        .mindfulness: ["meditate", "breathe", "breathing", "journal", "gratitude", "rest", "unplug",
                       "pray", "reflect", "relax", "calm"],
    ]

    static func obviousCategory(_ title: String) -> HabitCategory? {
        let words = Set(title.lowercased().split { !$0.isLetter }.map(String.init))
        let hits = plainWords.filter { !$0.value.isDisjoint(with: words) }.map(\.key)
        return hits.count == 1 ? hits[0] : nil
    }

    /// A suggested routine, as one of three patterns a person can read in a
    /// glance: every day, weekdays or weekends, always including today
    /// (a line that skipped today would not even appear on today's plan).
    /// The model gave "Mon Tue Wed Thu Fri Sat", which is a sentence where
    /// two words should be.
    static func snap(_ days: Set<Int>, today: Int) -> Set<Int> {
        guard !days.isEmpty else { return [] }
        if days.count >= 5 { return Set(1...7) }
        let weekend: Set<Int> = [1, 7]
        return weekend.contains(today) ? weekend : Set(2...6)
    }

    /// One to four words, verb first as written, no emoji, no closing
    /// punctuation, a capital to start.
    static func tidy(_ title: String) -> String {
        let plain = String(String.UnicodeScalarView(title.unicodeScalars.filter {
            !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C))
        }))
        let words = plain.split(whereSeparator: \.isWhitespace).prefix(maxWords)
        var text = words.joined(separator: " ")
        while let last = text.last, ".!?,;:".contains(last) || last.isWhitespace { text.removeLast() }
        guard let first = text.first else { return "" }
        return first.uppercased() + text.dropFirst()
    }

    static func key(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Something that suggests: Apple's model on a phone that has it, a fixed
/// list in tests and in the simulator's screenshots.
protocol PlanSuggester: Sendable {
    func suggest(_ context: PlanSuggestionContext) async throws -> [PlanSuggestion]
}

enum PlanSuggestions {
    /// Whether Suggest is offered at all. On a phone without Apple
    /// Intelligence the plan is exactly what it was.
    static var isAvailable: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-strataFakeSuggestions") { return true }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// Loads the model while the plan is open, before anyone asks.
    @MainActor static func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAvailable { OnDevicePlanSuggester.prewarm() }
        #endif
    }

    static var suggester: PlanSuggester {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-strataFakeSuggestions") { return FixedPlanSuggester() }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return OnDevicePlanSuggester() }
        #endif
        return FixedPlanSuggester()
    }
}

/// A fixed answer, for tests and the simulator.
nonisolated struct FixedPlanSuggester: PlanSuggester {
    var answers: [PlanSuggestion] = [
        PlanSuggestion(title: "Walk ten minutes", category: .health, size: .small, repeatDays: []),
        PlanSuggestion(title: "Text a friend", category: .social, size: .small, repeatDays: []),
        PlanSuggestion(title: "Stretch after coffee", category: .mindfulness, size: .small,
                       repeatDays: [2, 3, 4, 5, 6]),
        PlanSuggestion(title: "Sketch for fun", category: .creativity, size: .medium, repeatDays: []),
        PlanSuggestion(title: "Clear your inbox", category: .work, size: .medium, repeatDays: []),
        PlanSuggestion(title: "Read one chapter", category: .focus, size: .small, repeatDays: [1, 7]),
    ]

    func suggest(_ context: PlanSuggestionContext) async throws -> [PlanSuggestion] {
        PlanSuggestionRules.clean(answers.map { var s = $0; s.id = UUID(); return s }, context: context)
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
nonisolated struct OnDevicePlanSuggester: PlanSuggester {
    @Generable
    struct Plan {
        @Guide(description: "Exactly five varied plan lines.",
               .count(PlanSuggestionRules.asked))
        var lines: [Line]
    }

    @Generable
    struct Line {
        @Guide(description: "Specific and small, two to four plain words, verb first, with an amount or a moment. Example: Walk ten minutes")
        var title: String
        @Guide(description: "Its true category. health: body, movement, sleep, food. work: job, school, chores. creativity: making art, music, writing. focus: reading, studying, learning. social: friends, family. mindfulness: meditation, breathing, journaling, rest.",
               .anyOf(["health", "work", "creativity", "focus", "social", "mindfulness"]))
        var category: String
        @Guide(description: "small: under 15 minutes. medium: up to an hour. large: longer.",
               .anyOf(["small", "medium", "large"]))
        var size: String
        @Guide(description: "Weekdays it repeats on, 1 is Sunday and 7 is Saturday. Empty when it is just for today.",
               .maximumCount(7), .element(.range(1...7)))
        var repeatDays: [Int]
    }

    /// One session, made and warmed when the plan opens (`prewarm`), so the
    /// first Suggest does not wait for the model to load: measured in the
    /// simulator, a cold first answer took about 25 seconds. A fresh one
    /// for each ask after, so Others is not steered by a long transcript.
    @MainActor private static var warm: LanguageModelSession?

    @MainActor static func prewarm() {
        guard warm == nil, SystemLanguageModel.default.isAvailable else { return }
        let session = LanguageModelSession(instructions: PlanSuggestionRules.instructions)
        session.prewarm()
        warm = session
    }

    func suggest(_ context: PlanSuggestionContext) async throws -> [PlanSuggestion] {
        let session = await MainActor.run {
            defer { Self.warm = nil }
            return Self.warm ?? LanguageModelSession(instructions: PlanSuggestionRules.instructions)
        }
        let response = try await session.respond(to: context.prompt, generating: Plan.self,
                                                 options: GenerationOptions(temperature: 0.8))
        let raw = response.content.lines.map { line in
            PlanSuggestion(title: line.title,
                           category: HabitCategory(rawValue: line.category) ?? .unlabeled,
                           size: line.size == "large" ? .hard : line.size == "medium" ? .medium : .small,
                           repeatDays: Set(line.repeatDays))
        }
        return PlanSuggestionRules.clean(raw, context: context)
    }
}
#endif
