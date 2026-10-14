import Foundation
import Testing
@testable import Strata

/// **The chat's small things** (`docs/qol-research-2026-10-13.md`): a line
/// that did not go says so (M1), a time only after an hour's gap (M5), one
/// line saying the chat is today's (M6), and no jump while you read (M7).
@MainActor
@Suite("Chat quiet details")
struct ChatQuietDetailsTests {
    let sam = UUID()

    func line(at date: Date) -> CrewMessage {
        CrewMessage(messageID: UUID(), crewID: CrewID(rawValue: "c"), senderProfileID: sam, crewDay: "2026-10-14",
                    text: "hi", createdAt: date)
    }

    @Test("a time stands over the day's first line and after an hour's gap, never between close lines")
    func times() {
        let nine = Date(timeIntervalSince1970: 1_760_430_000)
        let first = line(at: nine)
        #expect(ChatTimes.showsTime(first, after: nil))
        #expect(!ChatTimes.showsTime(line(at: nine.addingTimeInterval(59 * 60)), after: first))
        #expect(ChatTimes.showsTime(line(at: nine.addingTimeInterval(60 * 60)), after: first))
    }

    @Test("a new line follows you down only when it is yours or you are near the newest")
    func follow() {
        #expect(ChatFollow.follows(newLineIsMine: true, distanceFromFoot: 5000, screen: 700), "your own line")
        #expect(ChatFollow.follows(newLineIsMine: false, distanceFromFoot: 300, screen: 700), "near the newest")
        #expect(!ChatFollow.follows(newLineIsMine: false, distanceFromFoot: 1400, screen: 700), "reading higher up")
    }

    @Test("the chat says when it clears, at midnight or at this phone's time for the crew's midnight")
    func clears() throws {
        let now = Date(timeIntervalSince1970: 1_760_430_000)
        let la = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let ny = try #require(TimeZone(identifier: "America/New_York"))
        #expect(ChatClears.line(crewZone: la, here: la, now: now) == "Today's chat clears at midnight.")
        let elsewhere = ChatClears.line(crewZone: ny, here: la, now: now)
        #expect(elsewhere.hasPrefix("Today's chat clears at ") && elsewhere.hasSuffix(".") && elsewhere.contains("9"),
                "the crew's midnight in New York is 9 in Los Angeles: \(elsewhere)")
    }

    @Test("the words are the voice's own, with no long dash and no exclamation")
    func words() {
        #expect(CrewChatSheet.unsentWords == "That didn't send. Try once more.")
        for words in [CrewChatSheet.unsentWords, ChatClears.midnight] {
            #expect(!words.contains("\u{2014}") && !words.contains("!"))
        }
    }
}
