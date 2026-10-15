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
