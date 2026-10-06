import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

/// **One question about one of the day's wins, and it never writes.**
///
/// The journal's Suggest (`docs/superpowers/specs/2026-10-05-shared-wins-journal-doodles-design.md`,
/// section 2). The same shape as `PlanSuggestions`: Apple's model on the
/// phone, a fixed answer in tests, rules in code where they can be tested.
///
/// **Why a question and nothing else.** Day One's follow-up questions read as
/// an interview and people turned them off, and AI summaries read as bloat,
/// so "the helper asks and never writes". The question is shown as the
/// editor's placeholder: it puts no text in the note and is gone the moment a
/// letter is typed. One at a time, under 12 words, about a win the person
/// actually logged ("What made the early run happen?"). With no model, no
/// wins or an answer the rules refuse, it is the short fixed list.
nonisolated struct JournalQuestionContext: Equatable, Sendable {
    /// The day's win titles, untitled ones left out, each once.
    var wins: [String]
    /// What was asked before this ask, so Suggest again brings another.
    var alreadyAsked: [String]
    /// A past day's questions say "that day", never "today".
    var isToday: Bool
    /// **Who a win was with**, by its title: a win kept from a friend's tag
    /// says "with Sam" (the cohesion pass, 2026-10-05). The question that
    /// can come of it ("What was the run with Sam like?") is the best one
    /// the day has, and the model cannot ask it without being told.
    var company: [String: [String]] = [:]

    /// A win's title as the prompt says it: "Morning run (with Sam)".
    func said(_ title: String) -> String {
        guard let people = company[title], !people.isEmpty else { return title }
        return "\(title) (with \(people.formatted(.list(type: .and))))"
    }

    /// The prompt, in plain lines.
    var prompt: String {
        var lines = ["The wins they logged \(isToday ? "today" : "that day"): \(wins.prefix(8).map(said).joined(separator: ", "))."]
        if !alreadyAsked.isEmpty {
            lines.append("Already asked, ask something different: \(alreadyAsked.joined(separator: " "))")
        }
        lines.append("Ask one question about one of these wins.")
        return lines.joined(separator: "\n")
    }

    /// The day's win titles, from its `HabitLog`s by way of each one's habit.
    /// The one-tap "Win" says nothing a question could be about.
    @MainActor
    static func winTitles(on dateString: String, context: ModelContext) -> [String] {
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString == dateString },
            sortBy: [SortDescriptor(\.completedAt)])
        descriptor.relationshipKeyPathsForPrefetching = [\.habit]
        var seen = Set<String>()
        var out: [String] = []
        for log in (try? context.fetch(descriptor)) ?? [] {
            let title = (log.habit?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title != QuickWinService.untitled,
                  seen.insert(title.lowercased()).inserted else { continue }
            out.append(title)
        }
        return out
    }

    /// The people each of the day's wins was kept with, by title
    /// (`KeptWith`). Only wins kept from a crew tag have any.
    @MainActor
    static func company(on dateString: String, context: ModelContext,
                        defaults: UserDefaults = .standard) -> [String: [String]] {
        let descriptor = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString == dateString })
        var out: [String: [String]] = [:]
        for log in (try? context.fetch(descriptor)) ?? [] {
            let names = KeptWith.names(for: log.id, defaults: defaults)
            let title = (log.habit?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !names.isEmpty, !title.isEmpty, title != QuickWinService.untitled else { continue }
            out[title, default: []].append(contentsOf: names.filter { !(out[title] ?? []).contains($0) })
        }
        return out
    }
}

/// **Who a kept win was with.** A tagged win you Keep becomes a win of your
/// own with an id of its own (`TaggedWinKeeper`), and nothing on a
/// `HabitLog` says it came from Sam. Written here at Keep, by the new win's
/// id, on this phone only; read by Suggest. No schema change: a name next to
/// a win is a hint for a question, not part of the record.
nonisolated enum KeptWith {
    static let defaultsKey = "crews.keptWith"

    static func record(_ names: [String], for logID: UUID, defaults: UserDefaults = .standard) {
        let kept = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !kept.isEmpty else { return }
        var all = defaults.dictionary(forKey: defaultsKey) as? [String: [String]] ?? [:]
        all[logID.uuidString] = kept
        defaults.set(all, forKey: defaultsKey)
    }

    static func names(for logID: UUID, defaults: UserDefaults = .standard) -> [String] {
        (defaults.dictionary(forKey: defaultsKey) as? [String: [String]])?[logID.uuidString] ?? []
    }
}

/// **Whatever the model says, cleaned to one short question or refused.** A
/// small model drifts: it answers its own question, asks two, runs long, or
/// asks about nothing in particular.
nonisolated enum JournalQuestionRules {
    /// Under twelve words in the spec; twelve is the most a question may be.
    static let maxWords = 12
    /// "Why?" is not a question anybody can start a note with.
    static let minWords = 3

    /// The owner's list, in the 5 Minute Journal style, for a phone with no
    /// model, a day with no wins, or an answer the rules refuse.
    static let fallback = [
        "What made today good?",
        "What are you glad you did?",
        "What would you do again?",
        "Who made today better?",
    ]

    /// The same list for a past day, which is not "today".
    static func fallback(isToday: Bool) -> [String] {
        isToday ? fallback : fallback.map { $0.replacingOccurrences(of: "today", with: "that day") }
    }

    /// The next one of the list that has not been asked, and round again
    /// once all four have.
    static func fallbackQuestion(after alreadyAsked: [String], isToday: Bool) -> String {
        let list = fallback(isToday: isToday)
        return list.first { !alreadyAsked.contains($0) } ?? list[0]
    }

    /// The owner's voice rules for a helper (2026-10-05, the same five as
    /// `PlanSuggestionRules.instructions`): it suggests only when asked,
    /// observes and never coaches, never sets a target, never mentions what
    /// was not done, and is calm and specific. The cleaning in `clean` is
    /// unchanged; these are what the model is told before it answers.
    static let instructions = """
        You help someone start a short journal note about their day.
        They pressed Suggest, so you ask exactly one question, and nothing else.
        Rules:
        - Ask about ONE of the wins they logged, using its own words.
        - If a win says who it was with, you may ask about that person.
        - Under twelve plain words, ending with a question mark.
        - Observe, never coach: no advice, no lessons, no "should".
        - Never set a goal or a target, and never ask about doing more.
        - Never mention anything they did not do.
        - Calm and specific, warm and curious, never a test: "What made the early run happen?"
        - Never answer it, never add a second sentence, never praise.
        - No emoji, no quotation marks.
        """

    /// One question, or nil.
    ///
    /// - First line only, cut straight after its first question mark: anything
    ///   after it is the model answering itself or asking a second.
    /// - No question mark, no question.
    /// - Leading numbering, bullets and quotes, and every emoji, go.
    /// - Three to twelve words. Too long is REFUSED, not cut: a question cut
    ///   at its twelfth word is no longer a question.
    /// - When the day has wins, it has to name one, by a word of its title.
    static func clean(_ raw: String, wins: [String]) -> String? {
        let line = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let plain = String(String.UnicodeScalarView(line.unicodeScalars.filter {
            !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C))
                && !"\"“”‘’`*".unicodeScalars.contains($0)
        }))
        guard let mark = plain.firstIndex(of: "?") else { return nil }
        var text = String(plain[...mark])
        // "1. ", "2) ", "- ", "• ".
        while let first = text.first, first.isNumber || "-•.) ".contains(first) || first.isWhitespace {
            text.removeFirst()
        }
        let words = text.split(whereSeparator: \.isWhitespace)
        guard (minWords...maxWords).contains(words.count) else { return nil }
        text = words.joined(separator: " ")
        guard let first = text.first else { return nil }
        text = first.uppercased() + text.dropFirst()
        guard wins.isEmpty || namesAWin(text, wins: wins) else { return nil }
        return text
    }

    /// Words too common to say which win a question is about.
    static let common: Set<String> = [
        "the", "and", "for", "you", "your", "with", "what", "who", "how", "why", "did", "was",
        "today", "day", "made", "make", "about", "that", "this", "from", "into", "get", "got",
    ]

    /// Shares a word with a win's title. A word counts if one is the start of
    /// the other, so "running" names "Morning run".
    static func namesAWin(_ question: String, wins: [String]) -> Bool {
        let asked = significant(question)
        return wins.contains { win in
            significant(win).contains { title in
                asked.contains { $0.hasPrefix(title) || title.hasPrefix($0) }
            }
        }
    }

    private static func significant(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
            .filter { $0.count >= 3 && !common.contains($0) }
    }
}

/// Something that asks: Apple's model on a phone that has it, a fixed list in
/// tests and in the simulator's screenshots.
protocol JournalQuestioner: Sendable {
    /// The model's raw answer. `JournalQuestions.next` cleans it.
    func ask(_ context: JournalQuestionContext) async throws -> String
}

enum JournalQuestions {
    /// Whether Apple's model is on this phone. Suggest is offered either way:
    /// without it, it is the fixed list.
    static var isModelAvailable: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-strataFakeSuggestions") { return true }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// Loads the model while the journal is open, before anyone asks.
    @MainActor static func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isModelAvailable { OnDeviceJournalQuestioner.prewarm() }
        #endif
    }

    /// Nil when there is no model: the fixed list answers instead.
    static var questioner: JournalQuestioner? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-strataFakeSuggestions") { return FixedJournalQuestioner() }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isModelAvailable { return OnDeviceJournalQuestioner() }
        #endif
        return nil
    }

    /// The question to show. Never throws and never comes back empty: every
    /// way of not having a good question ends on the fixed list.
    static func next(_ context: JournalQuestionContext, using questioner: JournalQuestioner?) async -> String {
        let fallback = JournalQuestionRules.fallbackQuestion(after: context.alreadyAsked,
                                                             isToday: context.isToday)
        guard !context.wins.isEmpty, let questioner else { return fallback }
        guard let raw = try? await questioner.ask(context),
              let question = JournalQuestionRules.clean(raw, wins: context.wins),
              !context.alreadyAsked.contains(question) else { return fallback }
        return question
    }
}

/// A fixed answer, for tests and the simulator: the first not yet asked.
nonisolated struct FixedJournalQuestioner: JournalQuestioner {
    var answers: [String] = ["What made the early run happen?", "Who was with you for the run?"]

    func ask(_ context: JournalQuestionContext) async throws -> String {
        answers.first { answer in
            !context.alreadyAsked.contains(JournalQuestionRules.clean(answer, wins: context.wins) ?? answer)
        } ?? answers[0]
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
nonisolated struct OnDeviceJournalQuestioner: JournalQuestioner {
    @Generable
    struct Question {
        @Guide(description: "One short question about one of their wins, under twelve words, ending with a question mark. Example: What made the early run happen?")
        var question: String
    }

    /// Made and warmed when the journal opens, as the plan's is, so the first
    /// Suggest does not wait for the model to load. A fresh one after.
    @MainActor private static var warm: LanguageModelSession?

    @MainActor static func prewarm() {
        guard warm == nil, SystemLanguageModel.default.isAvailable else { return }
        let session = LanguageModelSession(instructions: JournalQuestionRules.instructions)
        session.prewarm()
        warm = session
    }

    func ask(_ context: JournalQuestionContext) async throws -> String {
        let session = await MainActor.run {
            defer { Self.warm = nil }
            return Self.warm ?? LanguageModelSession(instructions: JournalQuestionRules.instructions)
        }
        let response = try await session.respond(to: context.prompt, generating: Question.self,
                                                 options: GenerationOptions(temperature: 0.8))
        return response.content.question
    }
}
#endif
