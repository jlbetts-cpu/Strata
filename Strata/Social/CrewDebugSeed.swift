#if DEBUG
import Foundation
import UIKit

/// A pretend crew, so every crew screen can be built, captured and filmed in
/// the simulator without two iCloud accounts.
///
///     -strataCrews 1 -strataSeedCrew 4          a crew of four with today's wins
///     -strataSeedCrews 3                         three crews, for the list
///     -strataCrewDropEvery 3                     a friend posts every 3 seconds
///     -strataOpenCrew 0                          launch straight into the first crew
///     -strataOpenCrews 1                         launch straight into the list
///
/// Every friend is a real `SocialStore` on the same `FakeCrewWorld`, posting
/// through `post` exactly as a phone would, so what is seeded is a state the
/// app could actually get into.
extension DebugHarness {
    static var seedsCrew: Int? { argument("-strataSeedCrew").flatMap(Int.init) }
    static var seedCrewCount: Int { argument("-strataSeedCrews").flatMap(Int.init) ?? 1 }
    static var crewDropEvery: Double? { argument("-strataCrewDropEvery").flatMap(Double.init) }
    static var openCrew: Int? { argument("-strataOpenCrew").flatMap(Int.init) }
    static var opensCrewList: Bool { argument("-strataOpenCrews") == "1" }
    /// Wins already in each seeded crew's tower.
    static var seedCrewWins: Int { argument("-strataSeedCrewWins").flatMap(Int.init) ?? 7 }

    static let crewNames = ["Roommates", "", "Run Club", "Family", "Studio"]
    static let friendNames = ["Sam", "Ana", "Leo", "Kai", "Mia", "Theo", "Zoe"]
    static let friendWins: [(String, HabitCategory, BlockSize)] = [
        ("Gym", .health, .medium), ("Read 20 pages", .focus, .small), ("Cooked dinner", .creativity, .medium),
        ("Called Mom", .social, .small), ("Morning run", .health, .hard), ("Journal", .mindfulness, .small),
        ("Shipped it", .work, .medium), ("Sketch", .creativity, .small), ("Stretch", .health, .small),
        ("Deep work", .focus, .hard), ("Walk", .mindfulness, .medium), ("", .unlabeled, .small),
    ]

    @MainActor private static var friends: [SocialStore] = []

    /// Builds the crews. Runs once, at launch, when asked.
    @MainActor
    static func seedCrewIfAsked() async {
        guard let size = seedsCrew, CrewsFlag.isOn else { return }
        let store = SocialStore.shared
        guard let mine = store.cloud as? FakeCrewCloud, store.crews.isEmpty else { return }
        store.myFirstName = { ProfileStore.shared.name.isEmpty ? "Jayden" : ProfileStore.shared.name }
        let support = FileManager.default.temporaryDirectory.appending(path: "crew-seed", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: support)

        for c in 0..<max(1, min(seedCrewCount, CrewCaps.crews)) {
            guard let (crew, link) = try? await store.createCrew(name: crewNames[c % crewNames.count]) else { continue }
            let people = max(1, min(size, CrewCaps.members)) - 1
            for f in 0..<people {
                let me = UUID()
                let cloud = FakeCrewCloud(world: mine.world, me: me)
                let dir = support.appending(path: "\(c)-\(f)", directoryHint: .isDirectory)
                let friend = SocialStore(cloud: cloud, defaults: UserDefaults(suiteName: "crew-seed-\(c)-\(f)")!,
                                         directory: dir)
                friend.isEnabled = { true }
                let name = friendNames[(f + c) % friendNames.count]
                friend.myFirstName = { name }
                _ = try? await friend.accept(CrewInvite(url: link))
                let headDir = dir.appending(path: "head", directoryHint: .isDirectory)
                HeadStore.writeVersion2Fixture(to: headDir)
                await friend.setMyHead(CrewHeadPack.make(from: headDir))
                friends.append(friend)
            }
            // Today's tower: friends' wins and a couple of mine, interleaved.
            let crewFriends = friends.suffix(people)
            for i in 0..<seedCrewWins {
                let poster = (i % 4 == 3 || crewFriends.isEmpty) ? store : crewFriends[crewFriends.startIndex + (i % crewFriends.count)]
                await poster.post(win(i, minutesAgo: (seedCrewWins - i) * 23), to: [crew.id])
            }
        }
        await store.refresh()
        if let index = openCrew, store.crews.indices.contains(index) {
            CrewRouter.shared.open = store.crews[index].id
        }
        if let every = crewDropEvery { startDropping(every: every) }
    }

    @MainActor
    private static func startDropping(every seconds: Double) {
        Task { @MainActor in
            var i = 100
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                guard let friend = friends.randomElement(),
                      let crew = friend.crews.first ?? SocialStore.shared.crews.first else { continue }
                await friend.refresh()
                await friend.post(win(i, minutesAgo: 0), to: [crew.id])
                await SocialStore.shared.refresh()
                i += 1
            }
        }
    }

    private static func win(_ i: Int, minutesAgo: Int) -> OwnWin {
        let (title, colour, size) = friendWins[i % friendWins.count]
        let date = Date().addingTimeInterval(-Double(minutesAgo) * 60)
        let photo = i % 3 == 1 ? UIImage(named: "DemoPhoto\(1 + i % 12)")?.jpegData(compressionQuality: 0.8) : nil
        return OwnWin(winID: UUID(), title: title, colour: colour, icon: colour, blockSize: size,
                      photoJPEG: photo, cropX: nil, cropY: nil, createdAt: date, updatedAt: date)
    }
}
#endif
