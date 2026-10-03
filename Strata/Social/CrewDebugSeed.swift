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
        NSLog("[strata-crew] seeding %d, cloud %@, crews %d", size, String(describing: type(of: store.cloud)), store.crews.count)
        guard let mine = store.cloud as? FakeCrewCloud, store.crews.isEmpty else { return }
        // `-strataCrewAge under13|teen|adult`; adult otherwise, so the seed's
        // photos travel.
        CrewAge.save(argument("-strataCrewAge").flatMap(CrewAge.init(rawValue:)) ?? .adult)
        // No permission prompt over the captures: a person sees it when they
        // start or join a crew, which the seed only pretends to do.
        store.announces = false
        defer { store.announces = true }
        store.myFirstName = { ProfileStore.shared.name.isEmpty ? "Jayden" : ProfileStore.shared.name }
        let support = FileManager.default.temporaryDirectory.appending(path: "crew-seed", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: support)

        for c in 0..<max(1, min(seedCrewCount, CrewCaps.crews)) {
            let made: (crew: Crew, invite: URL)
            // Every crew starts with its photo.
            let picture = UIImage(named: ["DemoPhoto3", "DemoPhoto7", "DemoPhoto5", "DemoPhoto1", "DemoPhoto6"][c % 5])?
                .jpegData(compressionQuality: 0.8)
            do { made = try await store.createCrew(name: crewNames[c % crewNames.count], photoJPEG: picture) } catch {
                NSLog("[strata-crew] createCrew failed: %@", String(describing: error))
                continue
            }
            let (crew, link) = made
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
                // Every third friend has no head, only a profile photo, so
                // the mixed circles can be seen.
                if f % 3 == 2 {
                    let face = UIImage(named: ["DemoPhoto8", "DemoPhoto6", "CreatorPortrait"][(f + c) % 3])?
                        .jpegData(compressionQuality: 0.8)
                    await friend.setMyHead(nil, photo: face.flatMap { ShareDerivative.jpeg(from: $0, longEdge: 600) })
                } else {
                    let headDir = dir.appending(path: "head", directoryHint: .isDirectory)
                    HeadStore.writeVersion2Fixture(to: headDir)
                    await friend.setMyHead(CrewHeadPack.make(from: headDir))
                }
                friends.append(friend)
            }
            // Today's tower: friends' wins and a couple of mine, interleaved.
            let crewFriends = friends.suffix(people)
            for i in 0..<seedCrewWins {
                let poster = (i % 4 == 3 || crewFriends.isEmpty) ? store : crewFriends[crewFriends.startIndex + (i % crewFriends.count)]
                await poster.post(win(i, minutesAgo: (seedCrewWins - i) * 23), to: [crew.id])
            }
        }
        // Friends react to a few wins, yours among them.
        for friend in friends {
            await friend.refresh()
            for crew in friend.crews {
                let wins = friend.today(in: crew.id).filter { $0.senderProfileID != friend.me }
                for (i, win) in wins.enumerated() where i % 2 == 0 {
                    await friend.react((Reaction.quick + ["👏", "💪"])[(i / 2 + win.title.count) % 5], to: win.winID, in: crew.id)
                }
            }
        }
        await store.refresh()
        NSLog("[strata-crew] seeded %d crews", store.crews.count)
        // `-strataCrewParked <n>`: the first crew's bubble starts with n heads in it.
        if let n = argument("-strataCrewParked").flatMap(Int.init), let first = store.crews.first {
            // Yours too, last, when n asks for more than the others: the
            // bubble full is eight heads.
            var ids = first.others(than: store.me).prefix(n).map(\.profileID.uuidString)
            if ids.count < n { ids.append(store.me.uuidString) }
            UserDefaults.standard.set(ids, forKey: "crews.parked.\(first.id.rawValue)")
        }
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

    /// Decoded once each: a friend's phone would not be decoding our demo
    /// photos on OUR main thread, so a film of their posts must not either
    /// (it was the largest cost in a sample of one, 2026-10-02).
    @MainActor private static var demoPhotos: [Int: Data] = [:]
    @MainActor private static func demoPhoto(_ n: Int) -> Data? {
        if let cached = demoPhotos[n] { return cached }
        let data = UIImage(named: "DemoPhoto\(n)")?.jpegData(compressionQuality: 0.8)
        demoPhotos[n] = data
        return data
    }

    private static func win(_ i: Int, minutesAgo: Int) -> OwnWin {
        let (title, colour, size) = friendWins[i % friendWins.count]
        let date = Date().addingTimeInterval(-Double(minutesAgo) * 60)
        let photo = i % 3 == 1 ? demoPhoto(1 + i % 12) : nil
        return OwnWin(winID: UUID(), title: title, colour: colour, icon: colour, blockSize: size,
                      photoJPEG: photo, cropX: nil, cropY: nil, createdAt: date, updatedAt: date)
    }
}
#endif
