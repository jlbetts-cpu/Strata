#if DEBUG
import Foundation
import PencilKit
import UIKit

/// A pretend crew, so every crew screen can be built, captured and filmed in
/// the simulator without two iCloud accounts.
///
///     -strataCrews 1 -strataSeedCrew 4          a crew of four with today's wins
///     -strataSeedCrews 3                         three crews, for the list
///     -strataCrewDropEvery 3                     a friend posts every 3 seconds
///     -strataOpenCrew 0                          launch straight into the first crew
///     -strataOpenCrews 1                         launch straight into the list
///     -strataCrewTagMe 1                         a friend's win "with" you, so
///                                                "Sam added you to a win" asks
///     -strataSeedCrewChat 1                      a few lines in today's chat,
///                                                a reply quoting your win among
///                                                them (also with -strataCrewSheet chat)
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
    /// `-strataSeedCrewHistory <days>`: everyone joined that many days ago,
    /// and the crew has that many days of numbers, so its streak, its chart
    /// and its saved days can be seen.
    static var seedCrewHistory: Int? { argument("-strataSeedCrewHistory").flatMap(Int.init) }

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
            let back = Double(seedCrewHistory ?? 0) * 86_400
            store.now = { Date().addingTimeInterval(-back) }
            defer { store.now = Date.init }
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
                friend.now = { Date().addingTimeInterval(-back) }
                _ = try? await friend.accept(CrewInvite(url: link))
                friend.now = Date.init
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
            store.now = Date.init
            // Today's tower: friends' wins and a couple of mine, interleaved.
            let crewFriends = friends.suffix(people)
            if let days = seedCrewHistory, days > 0 {
                // The last three days, still in the cloud: everyone posted,
                // so the streak runs into today.
                for ago in 1...3 {
                    for (k, poster) in ([store] + Array(crewFriends)).enumerated() {
                        await poster.post(win(ago * 5 + k, minutesAgo: ago * 1440 - k * 17), to: [crew.id])
                    }
                }
                var history = CrewHistory()
                let zone = crew.timeZone
                let today = CrewDay.string(for: Date(), in: zone)
                let ids = [store.me] + crewFriends.map(\.me)
                for ago in 4...max(4, days) {
                    guard let day = CrewDay.day(today, offsetBy: -ago, in: zone) else { continue }
                    for (k, id) in ids.enumerated() {
                        // A gap every so often, so the best run is longer
                        // than the current one.
                        if k == 1, ago % 17 == 0 { continue }
                        history.days[day, default: [:]][id.uuidString] = 1 + (ago * 7 + k) % 3
                    }
                }
                store.debugSetHistory(history, for: crew.id)
            }
            for i in 0..<seedCrewWins {
                var poster = (i % 4 == 3 || crewFriends.isEmpty) ? store : crewFriends[crewFriends.startIndex + (i % crewFriends.count)]
                // With history seeded, the last friend has not posted yet
                // today, so the page has someone to wait on.
                if seedCrewHistory != nil, crewFriends.count > 1, poster === crewFriends.last { poster = store }
                await poster.post(win(i, minutesAgo: (seedCrewWins - i) * 23), to: [crew.id])
            }
            // A friend's Morning run, with you and one more of the crew, the
            // newest block in the tower.
            if argument("-strataCrewTagMe") == "1", let tagger = crewFriends.first {
                await tagger.refresh()
                var run = win(4, minutesAgo: 1)
                run.withPeople = [store.me] + crewFriends.dropFirst().prefix(1).map(\.me)
                await tagger.post(run, to: [crew.id])
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
        // `-strataCrewDoodle seed`: two friends doodle on your newest win, so
        // a doodle in the chat can be photographed (doodles are chat lines
        // since 2026-10-05).
        if argument("-strataCrewDoodle") == "seed" {
            for (k, friend) in friends.prefix(2).enumerated() {
                await friend.refresh()
                guard let crew = friend.crews.first,
                      let mine = friend.today(in: crew.id).last(where: { $0.senderProfileID == store.me }) else { continue }
                let size = CGSize(width: 320, height: 240)
                let drawing = k == 0 ? InkSamples.sunOverHill(in: size, width: 6)
                    : InkSamples.drawing([(0...30).map { i in
                        let a = Double(i) / 30 * 2 * .pi
                        // A heart, drawn in one line.
                        let x = 16 * pow(sin(a), 3), y = -(13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a))
                        return CGPoint(x: 160 + x * 7, y: 120 + y * 7)
                    }], width: 6)
                friend.canReply = { true }
                if let png = InkExport.doodlePNG(drawing) {
                    await friend.doodle(png, to: mine.winID, in: crew.id)
                }
            }
        }
        // `-strataSeedCrewChat 0` with the chat open: its empty state.
        let seedChatFlag = argument("-strataSeedCrewChat")
        if seedChatFlag == "1" || (argument("-strataCrewSheet") == "chat" && seedChatFlag != "0") {
            await seedChat(friends: friends, me: store)
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

    /// A morning's chat in the first crew: two friends, you, and a reply
    /// quoting your newest win, so the quoted line can be photographed.
    @MainActor
    private static func seedChat(friends: [SocialStore], me: SocialStore) async {
        guard let crew = me.crews.first else { return }
        let inCrew = friends.filter { $0.crew(crew.id) != nil }
        guard let first = inCrew.first else { return }
        let second = inCrew.dropFirst().first ?? first
        await first.refresh()
        await first.send("morning all ☀️", in: crew.id)
        await second.refresh()
        await second.send("who's up for a walk after work?", in: crew.id)
        await me.refresh()
        await me.send("me! 6ish?", in: crew.id)
        await first.refresh()
        if let mine = first.today(in: crew.id).last(where: { $0.senderProfileID == me.me && !$0.title.isEmpty }) {
            await first.reply("so proud of you 🔥", to: mine.winID, in: crew.id)
        }
        await second.refresh()
        await second.send("6 works", in: crew.id)
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
