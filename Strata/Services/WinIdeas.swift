import Foundation
import SwiftData

/// **Wins to tap, not to remember** (2026-10-06: testers "dont really post
/// really anything during there day maybe 1 or 2 max"; the owner approved
/// the recommended fixes).
///
/// Asked "What did you do?" with an empty field, people recall the one or
/// two things that felt big enough and lose the rest: recall favours the
/// salient, recognition finds the small (Kahneman et al. 2004, the Day
/// Reconstruction Method; Choe et al. 2017, semi-automated tracking). So the
/// add sheet offers wins to recognise, over the keyboard where QuickType's
/// words would be:
/// - your plan's lines still waiting today;
/// - what you log most days and have not logged today;
/// - then small ones, so the field also says what counts (Amabile and
///   Kramer's small wins: people discount minor progress unless shown it).
///
/// Typing narrows them, so the same row is the autocomplete for your own
/// usual wins. Nothing is chosen for you and nothing says you forgot.
nonisolated struct WinIdea: Equatable, Sendable, Identifiable {
    let title: String
    let category: HabitCategory
    var id: String { title.lowercased() }
}

nonisolated enum WinIdeas {
    static let limit = 8
    /// The days looked back for your usual wins, and how many separate days
    /// make one usual.
    static let lookback = 30
    static let usualDays = 2

    /// Small ones, in the voice of someone saying what they did.
    static let small: [WinIdea] = [
        WinIdea(title: "Drank some water", category: .health),
        WinIdea(title: "Made my bed", category: .mindfulness),
        WinIdea(title: "Replied to a message", category: .social),
        WinIdea(title: "Went outside", category: .health),
        WinIdea(title: "Ate a real meal", category: .health),
        WinIdea(title: "Tidied one thing", category: .focus),
        WinIdea(title: "Took my meds", category: .health),
        WinIdea(title: "Started the hard thing", category: .work),
        WinIdea(title: "Called someone", category: .social),
        WinIdea(title: "Made something", category: .creativity),
    ]

    /// A past win, as the ideas need it.
    struct Logged: Sendable {
        let title: String
        let category: HabitCategory
        let day: String
    }

    /// The row: plan lines, then usual wins, then small ones, each once, none
    /// already logged today, narrowed to those starting a word with what is
    /// typed. The small ones turn with the day so the row is not a fixture.
    static func pick(plan: [WinIdea], logged: [Logged], today: String, typed: String = "") -> [WinIdea] {
        let doneToday = Set(logged.filter { $0.day == today }.map { $0.title.lowercased() })
        var counts: [String: (idea: WinIdea, days: Set<String>)] = [:]
        for log in logged where log.day != today {
            let title = log.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title != QuickWinService.untitled else { continue }
            let key = title.lowercased()
            var entry = counts[key] ?? (WinIdea(title: title, category: log.category), [])
            entry.days.insert(log.day)
            counts[key] = entry
        }
        let usual = counts.values
            .filter { $0.days.count >= usualDays }
            .sorted { ($0.days.count, $0.idea.title) > ($1.days.count, $1.idea.title) }
            .map(\.idea)
        let turn = Int(PastWin.stableHash(today) % UInt64(small.count))
        let smalls = Array(small[turn...] + small[..<turn])

        var seen = doneToday
        var out: [WinIdea] = []
        let words = typed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for idea in plan + usual + smalls {
            let key = idea.id
            guard !idea.title.isEmpty, !seen.contains(key) else { continue }
            if !words.isEmpty {
                let starts = key.hasPrefix(words) || key.contains(" " + words)
                guard starts, key != words else { continue }
            }
            seen.insert(key)
            out.append(idea)
            if out.count == limit { break }
        }
        return out
    }

    /// The candidates from the store: today's plan lines still open, and the
    /// last `lookback` days of named wins.
    @MainActor
    static func candidates(context: ModelContext, now: Date = Date(), calendar: Calendar = .current)
        -> (plan: [WinIdea], logged: [Logged], today: String) {
        let today = DateUtils.dateString(from: now)
        let plan = ((try? context.fetch(FetchDescriptor<PlanItem>(sortBy: [SortDescriptor(\.order)]))) ?? [])
            .filter { $0.completedAt == nil && $0.belongs(on: now, calendar: calendar) }
            .map { WinIdea(title: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), category: $0.category) }
        let since = calendar.date(byAdding: .day, value: -lookback, to: now).map(DateUtils.dateString(from:)) ?? today
        var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.completed && $0.dateString >= since })
        d.relationshipKeyPathsForPrefetching = [\.habit]
        let logged = ((try? context.fetch(d)) ?? []).compactMap { log -> Logged? in
            guard let habit = log.habit else { return nil }
            return Logged(title: habit.title, category: habit.displayCategory, day: log.dateString)
        }
        return (plan, logged, today)
    }

    /// The open plan line with these words, ticked: the win already exists,
    /// so only the line is marked, never a second win logged.
    @MainActor
    static func tickPlanLine(named title: String, context: ModelContext, now: Date = Date()) {
        let all = (try? context.fetch(FetchDescriptor<PlanItem>())) ?? []
        guard let line = DayComposing.onPlan(title, in: all) else { return }
        line.completedAt = now
        try? context.save()
    }
}
