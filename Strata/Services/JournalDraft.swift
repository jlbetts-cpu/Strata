import Foundation
import SwiftData
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

/// **Write My Day: a short entry drafted from the day, for you to edit**
/// (the owner, 2026-10-15: "it would be cool if you got a short ai summary
/// put into your journal and like your journal will be more organized into
/// an actual journal entry that can be edited based on your images"; his
/// pick, "On-device draft").
///
/// **This changes a rule on purpose.** The journal's helper was settled as
/// one that "asks and never writes" (`JournalQuestions`, 2026-10-05), because
/// AI summaries read as bloat. He asked for the draft tonight, so it writes,
/// but only when pressed, only into an empty note, and in his voice rules:
/// short, first person, what happened and with whom, never advice. Apple's
/// model on the phone; what is in the photographs is recognised on the phone
/// too (`PhotoThings`). Nothing leaves it.
nonisolated struct JournalDraftContext: Equatable, Sendable {
    struct Win: Equatable, Sendable {
        let title: String
        /// "in the morning, a health win".
        var moment: String?
        var with: [String] = []
        /// Their own note on the win (`WinNote`), if they wrote one.
        var note: String?
    }

    var wins: [Win]
    /// What the day's photographs show, as plain words ("dog", "beach").
    var inPhotos: [String] = []
    var isToday: Bool

    var prompt: String {
        var lines = ["\(isToday ? "Today" : "That day") they logged these wins:"]
        for win in wins.prefix(10) {
            var line = "- \(win.title)"
            if let moment = win.moment { line += ", \(moment)" }
            if !win.with.isEmpty { line += ", with \(win.with.formatted(.list(type: .and)))" }
            if let note = win.note { line += ". Their note: \(note)" }
            lines.append(line)
        }
        if !inPhotos.isEmpty {
            lines.append("Their photos from the day show: \(inPhotos.prefix(8).joined(separator: ", ")).")
        }
        lines.append("Write their journal entry for the day.")
        return lines.joined(separator: "\n")
    }
}

nonisolated enum JournalDraftRules {
    /// A short entry: a few sentences, never an essay.
    static let maxWords = 90
    static let minWords = 8

    static let instructions = """
        You write a short private journal entry for someone, from the wins they logged.
        Rules:
        - First person, past tense, as they would write it: "I went for an early run."
        - Two to four short sentences. Plain, calm, specific.
        - Use their own words for each win. Mention who it was with when given.
        - You may mention what their photos show, plainly.
        - Never give advice, never set goals, never praise, never use exclamation marks.
        - Never mention anything they did not do, and never invent feelings or details.
        - No emoji, no quotation marks, no headings, no dashes between clauses.
        """

    /// The model's answer, in the app's voice, or nil.
    ///
    /// Emoji, quotation marks and exclamation marks go; a long dash becomes a
    /// comma; anything past the word limit is cut at the last whole sentence.
    static func clean(_ raw: String) -> String? {
        var text = String(String.UnicodeScalarView(raw.unicodeScalars.filter {
            !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C))
                && !"\"“”`*#".unicodeScalars.contains($0)
                // What an emoji is built from: the variation selector, the
                // joiner and the keycap's frame (a "1️⃣" left "1" and these).
                && ![0xFE0F, 0x200D, 0x20E3].contains($0.value)
        }))
        text = text.replacingOccurrences(of: " \u{2014} ", with: ", ")
            .replacingOccurrences(of: "\u{2014}", with: ", ")
            .replacingOccurrences(of: " \u{2013} ", with: ", ")
            .replacingOccurrences(of: "!", with: ".")
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            // What an emoji left behind: "with Sam ." is "with Sam."
            .replacingOccurrences(of: " .", with: ".")
            .replacingOccurrences(of: " ,", with: ",")
            .replacingOccurrences(of: "\u{2026}", with: ".")
        // A run of stops is one: "..." and "?!" (now "?.") end once.
        text = text.replacingOccurrences(of: #"([.?])[.?]+"#, with: "$1", options: .regularExpression)
        let words = text.split(separator: " ")
        guard words.count >= minWords else { return nil }
        if words.count > maxWords {
            let cut = words.prefix(maxWords).joined(separator: " ")
            guard let end = cut.lastIndex(where: { ".?".contains($0) }) else { return nil }
            text = String(cut[...end])
        }
        return text.isEmpty ? nil : text
    }
}

protocol JournalDrafter: Sendable {
    func draft(_ context: JournalDraftContext) async throws -> String
}

enum JournalDraft {
    /// Offered only where Apple's model is: without it there is no draft,
    /// and no button promising one.
    static var isAvailable: Bool { JournalQuestions.isModelAvailable }

    static var drafter: JournalDrafter? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-strataFakeSuggestions") { return FixedJournalDrafter() }
        #endif
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), JournalQuestions.isModelAvailable { return OnDeviceJournalDrafter() }
        #endif
        return nil
    }

    /// The day as the drafter is told it.
    @MainActor
    static func context(on dateString: String, isToday: Bool, context modelContext: ModelContext) async -> JournalDraftContext {
        var descriptor = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.dateString == dateString },
                                                   sortBy: [SortDescriptor(\.completedAt)])
        descriptor.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        let moments = JournalQuestionContext.moments(on: dateString, context: modelContext)
        let company = JournalQuestionContext.company(on: dateString, context: modelContext)
        var seen = Set<String>()
        var wins: [JournalDraftContext.Win] = []
        for log in logs where log.completed {
            let title = (log.habit?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title != QuickWinService.untitled, seen.insert(title.lowercased()).inserted else { continue }
            wins.append(.init(title: title, moment: moments[title], with: company[title] ?? [],
                              note: log.note.flatMap(WinNote.tidy)))
        }
        let photos = logs.compactMap(\.imageFileName)
        return JournalDraftContext(wins: wins, inPhotos: await PhotoThings.named(in: photos), isToday: isToday)
    }

    /// The entry, or nil when there is nothing to write from or the model's
    /// answer does not pass the rules.
    static func write(_ context: JournalDraftContext, using drafter: JournalDrafter?) async -> String? {
        guard !context.wins.isEmpty, let drafter, let raw = try? await drafter.draft(context) else { return nil }
        return JournalDraftRules.clean(raw)
    }
}

/// **What the day's photographs show**, in a few plain words, recognised on
/// the phone by Vision (no network): the strongest labels across them, once
/// each, without the vague ones ("structure", "material").
enum PhotoThings {
    static let vague: Set<String> = ["structure", "material", "document", "text", "screenshot", "adult",
                                     "people", "machine", "consumer_electronics", "liquid", "container"]

    static func named(in fileNames: [String]) async -> [String] {
        var scores: [String: Float] = [:]
        for name in fileNames.prefix(8) {
            guard let image = await ImageManager.shared.loadThumbnail(fileName: name, maxWidth: 360,
                                                                       lane: .prefetch, countsAsForeground: false),
                  let cg = image.cgImage else { continue }
            let found = await Task.detached(priority: .utility) { () -> [(String, Float)] in
                let request = VNClassifyImageRequest()
                try? VNImageRequestHandler(cgImage: cg).perform([request])
                return (request.results ?? []).filter { $0.confidence > 0.35 }.prefix(4)
                    .map { ($0.identifier, $0.confidence) }
            }.value
            for (label, confidence) in found where !vague.contains(label) {
                scores[label] = max(scores[label] ?? 0, confidence)
            }
        }
        return scores.sorted { $0.value > $1.value }.prefix(8)
            .map { $0.key.replacingOccurrences(of: "_", with: " ") }
    }
}

/// A fixed answer, for tests and the simulator's screenshots.
nonisolated struct FixedJournalDrafter: JournalDrafter {
    var answer = "I went for an early run before class and got through my inbox after. Cooked dinner with Sam in the evening, which was the best part of the day."

    func draft(_ context: JournalDraftContext) async throws -> String { answer }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
nonisolated struct OnDeviceJournalDrafter: JournalDrafter {
    @Generable
    struct Entry {
        @Guide(description: "Their journal entry: two to four short first-person sentences about the wins they logged, in their words, past tense.")
        var entry: String
    }

    func draft(_ context: JournalDraftContext) async throws -> String {
        let session = LanguageModelSession(instructions: JournalDraftRules.instructions)
        let response = try await session.respond(to: context.prompt, generating: Entry.self,
                                                 options: GenerationOptions(temperature: 0.6))
        return response.content.entry
    }
}
#endif
