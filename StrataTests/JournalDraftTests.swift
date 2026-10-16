import Foundation
import Testing
@testable import Strata

/// **Write My Day** (2026-10-15): a short first-person entry drafted from
/// the day's wins and photos, held to the app's voice.
@Suite("Write My Day")
struct JournalDraftTests {
    @Test("the model's answer is cleaned into the app's voice")
    func clean() {
        let raw = "I went for a run \u{2014} early! Then \"cooked dinner\" with Sam 🍝."
        #expect(JournalDraftRules.clean(raw) == "I went for a run, early. Then cooked dinner with Sam.")
        #expect(JournalDraftRules.clean("Too short.") == nil)
    }

    @Test("a run of stops ends once, and an emoji leaves nothing behind")
    func leftovers() {
        #expect(JournalDraftRules.clean("I finally finished the essay... and went to sleep early that night.")
                == "I finally finished the essay. and went to sleep early that night.")
        #expect(JournalDraftRules.clean("Who knew a walk could fix the whole afternoon?! I did, after class.")
                == "Who knew a walk could fix the whole afternoon? I did, after class.")
        #expect(JournalDraftRules.clean("I ran 5 miles 1\u{FE0F}\u{20E3} with Sam after class and felt good.")
                == "I ran 5 miles 1 with Sam after class and felt good.")
        #expect(JournalDraftRules.clean("Long day of studying\u{2026} then dinner at home with my roommates.")
                == "Long day of studying. then dinner at home with my roommates.")
    }

    @Test("a long answer is cut at its last whole sentence")
    func long() throws {
        let sentence = "I walked to class and read twenty pages on the way there."
        let raw = Array(repeating: sentence, count: 12).joined(separator: " ")
        let cut = try #require(JournalDraftRules.clean(raw))
        #expect(cut.split(separator: " ").count <= JournalDraftRules.maxWords)
        #expect(cut.hasSuffix("."))
    }

    @Test("the prompt carries the wins, who they were with, notes and what the photos show")
    func prompt() {
        let context = JournalDraftContext(wins: [
            .init(title: "Morning run", moment: "in the morning, a health win", with: ["Sam"], note: "Cold out"),
            .init(title: "Inbox zero"),
        ], inPhotos: ["beach", "dog"], isToday: true)
        let prompt = context.prompt
        #expect(prompt.contains("Morning run, in the morning, a health win, with Sam. Their note: Cold out"))
        #expect(prompt.contains("- Inbox zero"))
        #expect(prompt.contains("beach, dog"))
    }

    @Test("no wins, no draft")
    func nothingToWrite() async {
        let empty = JournalDraftContext(wins: [], isToday: true)
        #expect(await JournalDraft.write(empty, using: FixedJournalDrafter()) == nil)
        let day = JournalDraftContext(wins: [.init(title: "Morning run")], isToday: true)
        #expect(await JournalDraft.write(day, using: FixedJournalDrafter()) != nil)
    }
}
