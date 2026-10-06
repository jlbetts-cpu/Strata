import Testing
import Foundation
@testable import Strata

/// Journaling from the day's photographs (the owner, 2026-10-06): the row
/// above the note, and a question about the one win a photo was pressed for.
@Suite("Journal: a question about the photo you pressed")
struct JournalPhotoTests {
    private func context(focus: String?, asked: [String] = []) -> JournalQuestionContext {
        JournalQuestionContext(wins: ["Ran 5k", "Cooked dinner"], alreadyAsked: asked, isToday: true,
                               focus: focus, moments: ["Ran 5k": "in the morning, a health win"])
    }

    @Test("the prompt is about the chosen win, with what is known about it")
    func promptIsAboutTheChosenWin() {
        let prompt = context(focus: "Ran 5k").prompt
        #expect(prompt.contains("Ran 5k, in the morning, a health win"))
        #expect(!prompt.contains("Cooked dinner"), "the prompt asks about the whole day again")
        #expect(prompt.contains("Ask one question about this win."))
        // Without a photo pressed it is the day, as Suggest always was.
        #expect(context(focus: nil).prompt.contains("Cooked dinner"))
    }

    @Test("a question about another win is refused and the chosen win's own is used")
    func questionMustNameTheChosenWin() async {
        let offTopic = FixedJournalQuestioner(answers: ["What made dinner taste so good?"])
        let question = await JournalQuestions.next(context(focus: "Ran 5k"), using: offTopic)
        #expect(question.contains("Ran 5k"), "\(question) is not about the photo that was pressed")
        let onTopic = FixedJournalQuestioner(answers: ["Who ran the 5k with you?"])
        #expect(await JournalQuestions.next(context(focus: "Ran 5k"), using: onTopic) == "Who ran the 5k with you?")
    }

    @Test("without the model, each fallback names the win and none repeats")
    func fallbacksNameTheWin() async {
        var asked: [String] = []
        for _ in 0..<3 {
            let q = await JournalQuestions.next(context(focus: "Ran 5k", asked: asked), using: nil)
            #expect(q.contains("Ran 5k"))
            #expect(!asked.contains(q), "\(q) was asked twice")
            #expect(JournalQuestionRules.namesAWin(q, wins: ["Ran 5k"]))
            asked.append(q)
        }
    }

    @Test("the part of the day reads as a person would say it")
    func partOfDay() {
        let calendar = Calendar(identifier: .gregorian)
        func at(_ hour: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour))! }
        #expect(JournalQuestionContext.partOfDay(at(8), calendar: calendar) == "in the morning")
        #expect(JournalQuestionContext.partOfDay(at(14), calendar: calendar) == "in the afternoon")
        #expect(JournalQuestionContext.partOfDay(at(19), calendar: calendar) == "in the evening")
        #expect(JournalQuestionContext.partOfDay(at(2), calendar: calendar) == "at night")
    }

    @Test("the voice rules still say never to speak as if it noticed")
    func noNoticing() {
        #expect(JournalQuestionRules.instructions.contains("as if you had noticed it"))
    }

    /// The row of the day's photographs above the note came out (the owner,
    /// 2026-10-06: "why is there pictures in the journal tab I dont think i
    /// like that"). The question about one win stays, for Suggest.
    @Test("the journal has no row of photographs")
    func noPhotoRow() throws {
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(!sheet.contains("JournalPhotoRow("))
        #expect((try? SourceSweep.read("Strata/Views/JournalPhotoRow.swift")) == nil, "the row's file is back")
    }
}
