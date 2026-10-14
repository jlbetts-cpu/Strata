import Foundation
import SwiftData
import Testing
@testable import Strata

/// **Friends' reactions on your own wins** (the owner, 2026-10-13:
/// "reactions on main wins and memories with lots of reactions").
@MainActor
@Suite("Reactions on your own wins")
struct MyWinReactionsTests {
    private let me = UUID(), sam = UUID(), ana = UUID(), jo = UUID()
    private let crewA = CrewID(rawValue: "a"), crewB = CrewID(rawValue: "b")
    private let noon = Date(timeIntervalSince1970: 1_791_900_000)

    private func win(_ id: UUID = UUID(), in crew: CrewID, by who: UUID) -> SharedWin {
        SharedWin(winID: id, crewID: crew, senderProfileID: who, crewDay: "2026-10-13", title: "Run",
                  colour: .health, icon: .health, blockSize: .small, photo: nil, cropX: nil, cropY: nil,
                  createdAt: noon, updatedAt: noon)
    }

    private func reaction(_ emoji: String, to win: UUID, in crew: CrewID, by who: UUID, at minutes: Double = 0) -> Reaction {
        Reaction(winID: win, crewID: crew, profileID: who, emoji: emoji, createdAt: noon.addingTimeInterval(minutes * 60))
    }

    @Test("gathered across every crew the win went to, keyed by the win")
    func acrossCrews() {
        let id = UUID()
        let got = MyWinReactions.gather(
            reactionsByCrew: [crewA: [reaction("🔥", to: id, in: crewA, by: sam)],
                              crewB: [reaction("👑", to: id, in: crewB, by: ana, at: 1)]],
            winsByCrew: [crewA: [win(id, in: crewA, by: me)], crewB: [win(id, in: crewB, by: me)]],
            me: me, blocked: [])
        #expect(got[id]?.map(\.emoji) == ["🔥", "👑"])
    }

    @Test("only friends, only on your wins: never yours, a blocked person's, a friend's win, or a chat line")
    func onlyFriendsOnYours() {
        let mine = UUID(), theirs = UUID(), line = UUID()
        let got = MyWinReactions.gather(
            reactionsByCrew: [crewA: [reaction("🔥", to: mine, in: crewA, by: me),
                                      reaction("👑", to: mine, in: crewA, by: jo),
                                      reaction("❤️", to: theirs, in: crewA, by: ana),
                                      reaction("😂", to: line, in: crewA, by: sam)]],
            winsByCrew: [crewA: [win(mine, in: crewA, by: me), win(theirs, in: crewA, by: sam)]],
            me: me, blocked: [jo])
        #expect(got[mine] == nil)
        #expect(got[theirs] == nil)
        #expect(got[line] == nil)
    }

    @Test("a friend in two of your crews counts once, with their latest")
    func onceAPerson() {
        let id = UUID()
        let got = MyWinReactions.gather(
            reactionsByCrew: [crewA: [reaction("🔥", to: id, in: crewA, by: sam)],
                              crewB: [reaction("👑", to: id, in: crewB, by: sam, at: 5)]],
            winsByCrew: [crewA: [win(id, in: crewA, by: me)], crewB: [win(id, in: crewB, by: me)]],
            me: me, blocked: [])
        #expect(got[id]?.map(\.emoji) == ["👑"])
    }

    @Test("many reactions stay tidy: the most given emoji first, and the total")
    func tidy() throws {
        let container = try ModelContainer(for: Habit.self, HabitLog.self, Tower.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        _ = try QuickWinService.logWin(title: "Run", category: .health, size: .small, on: noon,
                                       context: context, tower: nil)
        let log = try #require(try context.fetch(FetchDescriptor<HabitLog>()).first)
        let people = (0..<9).map { _ in UUID() }
        let given = people.enumerated().map { i, who in
            reaction(i < 5 ? "🔥" : (i < 8 ? "👑" : "❤️"), to: log.id, in: crewA, by: who, at: Double(i))
        }
        let vm = TowerViewModel()
        vm.buildTower(from: [log], reactions: [log.id: given])
        let look = try #require(vm.placedBlocks.first?.look)
        #expect(look.reactionEmoji.first == "🔥")
        #expect(look.reactionCount == 9)
        #expect(look.myReaction == nil, "your own tower never marks one as yours")
        #expect(look.standsAlone, "a block with a badge is not folded into a run")

        let bare = TowerViewModel()
        bare.buildTower(from: [log])
        #expect(bare.placedBlocks.first?.look.reactionCount == 0)
    }

    @Test("wired on Wins and in a day of Memories, and rebuilt when one arrives")
    func wired() throws {
        let main = SourceSweep.code(try SourceSweep.read("Strata/Views/MainAppView.swift"))
        #expect(main.components(separatedBy: "reactions: SocialStore.reactionsForMyTower").count - 1 == 2)
        #expect(main.contains(".modifier(MyWinReactionsWatch { _ = refreshData() })"))
        let day = SourceSweep.code(try SourceSweep.read("Strata/Views/DayAlbumDetailView.swift"))
        #expect(day.contains("reactions: SocialStore.reactionsForMyTower"))
        #expect(day.contains(".onChange(of: SocialStore.reactionsForMyTower) { reload() }"))
    }
}
