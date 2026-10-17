import Testing
@testable import Strata

/// The story reply's Send key, told from a paste (2026-10-18).
@Suite("The story reply's Send key")
struct StoryReplyKeyTests {
    @Test("the key alone sends")
    func key() { #expect(StoryReplyKey.isSend(before: "so good", typed: "so good\n")) }

    @Test("the key with autocorrect finishing the last word sends")
    func autocorrect() { #expect(StoryReplyKey.isSend(before: "That view thoug", typed: "That view though\n")) }

    @Test("a paste with lines in it does not send")
    func paste() {
        #expect(!StoryReplyKey.isSend(before: "", typed: "first line\nsecond line"))
        #expect(!StoryReplyKey.isSend(before: "", typed: "first line\nsecond line\n"))
    }

    @Test("no new line, no send")
    func typing() { #expect(!StoryReplyKey.isSend(before: "so", typed: "so g")) }
}
