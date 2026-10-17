import Foundation
import Testing
@testable import Strata

/// The page you talk to someone on, made theirs and yours (2026-10-17).
struct BetweenYouTests {
    let me = UUID(), sam = UUID(), ana = UUID()
    let crew = CrewID(rawValue: "c")

    func win(_ id: UUID = UUID(), by sender: UUID, _ title: String, day: String = "2026-10-16", ago: TimeInterval = 0) -> SharedWin {
        SharedWin(winID: id, crewID: crew, senderProfileID: sender, crewDay: day, title: title,
                  colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                  createdAt: Date().addingTimeInterval(-ago), updatedAt: .now)
    }

    @Test("cheers between the two of you, and the same thing on the same day; nobody else's")
    func moments() {
        let gym = win(by: sam, "Gym", ago: 300), walk = win(by: me, "Walk", ago: 200)
        let theirWalk = win(by: sam, "walk ", ago: 100), anas = win(by: ana, "Read", ago: 50)
        let reactions = [
            Reaction(winID: gym.winID, crewID: crew, profileID: me, emoji: "🔥", createdAt: Date().addingTimeInterval(-90)),
            Reaction(winID: walk.winID, crewID: crew, profileID: sam, emoji: "❤️", createdAt: Date().addingTimeInterval(-80)),
            Reaction(winID: anas.winID, crewID: crew, profileID: me, emoji: "❤️", createdAt: Date().addingTimeInterval(-10)),
        ]
        let found = BetweenYou.moments(me: me, friend: sam, name: "Sam", wins: [gym, walk, theirWalk, anas], reactions: reactions)
        #expect(found.map(\.words) == ["Sam cheered your Walk ❤️", "You cheered Sam's Gym 🔥", "You both did Walk"], "newest first")
        #expect(!found.contains { $0.words.contains("Read") }, "a cheer for someone else is not between you")
        #expect(found.allSatisfy { !$0.words.contains(where: \.isNumber) }, "words, never a tally")
    }

    @Test("at most a few, newest first")
    func few() {
        let wins = (0..<10).map { win(by: sam, "Thing \($0)", ago: Double($0)) }
        let reactions = wins.map { Reaction(winID: $0.winID, crewID: crew, profileID: me, emoji: "❤️", createdAt: $0.createdAt) }
        let found = BetweenYou.moments(me: me, friend: sam, name: "Sam", wins: wins, reactions: reactions)
        #expect(found.count == BetweenYou.most)
    }
}
