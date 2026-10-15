import Testing
import Foundation
@testable import Strata

@Suite("Chat craft: big emoji and links")
struct ChatCraftTests {
    @Test("one to three emoji are big, words are not")
    func bigEmoji() {
        #expect(ChatEmoji.isBig("🔥"))
        #expect(ChatEmoji.isBig("🔥👏 🙌"))
        #expect(ChatEmoji.isBig("❤️"))
        #expect(ChatEmoji.isBig("👍🏽"))
        #expect(!ChatEmoji.isBig("🔥🔥🔥🔥"))
        #expect(!ChatEmoji.isBig("nice 🔥"))
        #expect(!ChatEmoji.isBig("6"))
        #expect(!ChatEmoji.isBig(""))
    }

    @Test("a web address is a link, plain words are not")
    func links() {
        #expect(ChatLinks.hasLink("look at https://apple.com/ios"))
        #expect(ChatLinks.hasLink("www.strava.com/clubs"))
        #expect(!ChatLinks.hasLink("see you at 6"))
        #expect(!ChatLinks.hasLink("call 555 0100"))
    }
}

@Suite("Reply starters")
struct ReplyStarterTests {
    @Test("a friend's win gets three starters that read with any title")
    func friends() {
        let lines = ReplyStarters.lines(title: "Shipped it", mine: false)
        #expect(lines.count == 3)
        #expect(lines.first == "How did it go?")
        #expect(!lines.contains { $0.contains("Shipped it") })
    }

    @Test("your own win gets none")
    func yours() {
        #expect(ReplyStarters.lines(title: "Gym", mine: true).isEmpty)
    }
}

@Suite("Names are checked by whole words")
struct NameWordsTests {
    @Test("ordinary names that only begin with or run into a refused term pass")
    func innocentNames() {
        #expect(CrewWords.isAcceptableName("Kyson"))
        #expect(CrewWords.isAcceptableName("Mango diet"))
        #expect(CrewWords.isAcceptableName("Go Diego"))
        #expect(CrewWords.isAcceptableName("Spicy noodles"))
        #expect(CrewWords.kept("Kyson") == "Kyson")
    }

    @Test("a refused word or phrase in a name is caught")
    func refusedNames() {
        #expect(!CrewWords.isAcceptableName("kys"))
        #expect(!CrewWords.isAcceptableName("Go die now"))
        #expect(!CrewWords.isAcceptableName("k y s"))
        // A refused word with an ending is the same word.
        #expect(!CrewWords.isAcceptableName("the sluts"))
        #expect(!CrewWords.isAcceptableName("Retarded crew"))
        #expect(CrewWords.isAcceptableName("Spicing it up"))
        #expect(CrewWords.kept("go die") == "")
    }

    @Test("a refused crew name is shown as an unnamed crew, and kept raw")
    func crewName() {
        let me = UUID()
        let crew = Crew(id: CrewID(rawValue: "c"), name: "go die", ownerProfileID: me, timeZoneIdentifier: "UTC",
                        createdAt: .distantPast, photo: nil,
                        members: [CrewMember(profileID: me, firstName: "Me", joinedAt: .distantPast),
                                  CrewMember(profileID: UUID(), firstName: "Sam", joinedAt: .distantPast)])
        #expect(crew.displayName(excluding: me) == "Sam")
        #expect(crew.name == "go die")
    }
}
