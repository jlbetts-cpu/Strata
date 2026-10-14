import Foundation
import Testing
@testable import Strata

/// A crew's row says its newest thing, whatever it is, and opens on the
/// chat when that thing was said there (the owner, 2026-10-13).
@MainActor
@Suite("A crew's newest thing")
struct CrewActivityTests {
    private let me = UUID(), sam = UUID()
    private let crew = CrewID(rawValue: "c1")
    private let noon = Date(timeIntervalSince1970: 1_791_900_000)

    private func win(_ title: String, by who: UUID, at minutes: Double, photo: URL? = nil) -> SharedWin {
        SharedWin(winID: UUID(), crewID: crew, senderProfileID: who, crewDay: "2026-10-13", title: title,
                  colour: .health, icon: .health, blockSize: .small, photo: photo, cropX: nil, cropY: nil,
                  createdAt: noon.addingTimeInterval(minutes * 60), updatedAt: noon.addingTimeInterval(minutes * 60))
    }
    private func line(_ text: String, by who: UUID, at minutes: Double) -> CrewMessage {
        CrewMessage(messageID: UUID(), crewID: crew, senderProfileID: who, crewDay: "2026-10-13", text: text,
                    createdAt: noon.addingTimeInterval(minutes * 60))
    }
    private func name(_ id: UUID) -> String { id == sam ? "Sam" : "A friend" }

    @Test("a message newer than the last win is the row's line, and it opens the chat")
    func messageWins() throws {
        let newest = try #require(CrewActivity.newest(wins: [win("Gym", by: sam, at: 1)],
                                                      messages: [line("who's up for a walk", by: sam, at: 5)],
                                                      reactions: [], me: me))
        #expect(newest.preview(name: name, me: me) == "Sam: who's up for a walk")
        #expect(CrewsListView.newsIsChat(newest))
    }

    @Test("a friend's reaction to your win says so, in the voice's own words, and opens the tower")
    func reactionToYours() throws {
        let mine = win("Morning run", by: me, at: 1)
        let reaction = Reaction(winID: mine.winID, crewID: crew, profileID: sam, emoji: "🔥",
                                createdAt: noon.addingTimeInterval(10 * 60))
        let newest = try #require(CrewActivity.newest(wins: [mine], messages: [], reactions: [reaction], me: me))
        #expect(newest.preview(name: name, me: me) == "Sam reacted 🔥 to your win")
        #expect(!CrewsListView.newsIsChat(newest))
    }

    @Test("your own reactions are not news; a win is still the line when it is newest")
    func ownReactionIgnored() throws {
        let theirs = win("Gym", by: sam, at: 3)
        let mineReacting = Reaction(winID: theirs.winID, crewID: crew, profileID: me, emoji: "👑",
                                    createdAt: noon.addingTimeInterval(20 * 60))
        let newest = try #require(CrewActivity.newest(wins: [theirs], messages: [], reactions: [mineReacting], me: me))
        #expect(newest.preview(name: name, me: me) == "Sam added Gym")
    }

    @Test("a strip, a plan line and a doodle are said in words, never as invisible marks")
    func specialLines() {
        var strip = line(CrewMessage.stripMarker, by: sam, at: 1)
        strip.sketch = URL(fileURLWithPath: "/tmp/strip.png")
        #expect(CrewActivity.message(strip).preview(name: name, me: me) == "Sam sent a strip")
        var doodle = line("", by: sam, at: 1)
        doodle.sketch = URL(fileURLWithPath: "/tmp/d.png")
        #expect(CrewActivity.message(doodle).preview(name: name, me: me) == "Sam sent a doodle")
        let mine = line("me! 6ish?", by: me, at: 1)
        #expect(CrewActivity.message(mine).preview(name: name, me: me) == "You: me! 6ish?")
    }

    @Test("the list is ordered by it, newest first")
    func ordered() throws {
        let code = SourceSweep.code(try SourceSweep.read("Strata/Views/Crews/CrewsListView.swift"))
        #expect(code.contains("(store.activity(in: a.id)?.date ?? .distantPast) > (store.activity(in: b.id)?.date ?? .distantPast)"))
        #expect(code.contains("let latest = store.activity(in: crew.id)"), "the row went back to wins only")
    }
}
