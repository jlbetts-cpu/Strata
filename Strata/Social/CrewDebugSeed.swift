#if DEBUG
import Foundation
import PencilKit
import SwiftUI
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
///     -strataFriendSaysEvery 6                   a friend writes a line in the
///                                                first crew's chat every 6
///                                                seconds, so the line over the
///                                                Wins tower can be seen
///                                                (`WinsChatBanner`)
///     -strataChatReact seed|open                 friends react to the chat's
///                                                lines, an emoji pair and a
///                                                sticker among them; "open"
///                                                also holds a friend's line so
///                                                its bar shows
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

    /// `-strataSeedInvite 1`: a friend's crew this phone is not in, and its
    /// invitation opened a few seconds after launch, as a tap on the link
    /// in Messages would: the rules, the join, then the crew.
    @MainActor
    static func seedInviteIfAsked() async {
        guard argument("-strataSeedInvite") != nil, CrewsFlag.isOn else { return }
        let store = SocialStore.shared
        NSLog("[strata-invite] cloud %@, crews %d", String(describing: type(of: store.cloud)), store.crews.count)
        // Whatever crews an earlier run left on this simulator do not matter
        // here: the invitation is to a crew this phone is not in.
        guard let mine = store.cloud as? FakeCrewCloud else { return }
        CrewAge.save(.adult)
        store.announces = false
        let support = FileManager.default.temporaryDirectory.appending(path: "crew-invite-seed", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: support)
        func friend(_ name: String, _ i: Int) -> SocialStore {
            let made = SocialStore(cloud: FakeCrewCloud(world: mine.world, me: UUID()),
                                   defaults: UserDefaults(suiteName: "crew-invite-seed-\(i)")!,
                                   directory: support.appending(path: "\(i)", directoryHint: .isDirectory))
            made.isEnabled = { true }
            made.myFirstName = { name }
            made.myHandle = { name.lowercased() }
            return made
        }
        let host = friend("Sam", 0), other = friend("Ana", 1)
        let picture = UIImage(named: "DemoPhoto3")?.jpegData(compressionQuality: 0.8)
        let made: (crew: Crew, invite: URL)
        do { made = try await host.createCrew(name: "Roommates", photoJPEG: picture) } catch {
            NSLog("[strata-invite] createCrew failed: %@", String(describing: error))
            return
        }
        _ = try? await other.accept(CrewInvite(url: made.invite))
        for (k, poster) in [host, other, host, other].enumerated() {
            await poster.refresh()
            await poster.post(win(k, minutesAgo: 90 - k * 20), to: [made.crew.id])
        }
        friends.append(contentsOf: [host, other])
        try? await Task.sleep(for: .seconds(3))
        store.announces = true
        NSLog("[strata-invite] opening, gate %@", String(describing: CrewGate.current))
        // Past the link's reader, which a pretend cloud's address does not
        // satisfy: straight to what a read link does.
        CrewRouter.shared.join(CrewInvite(url: made.invite))
    }

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
                friend.myHandle = { name.lowercased() }
                friend.now = { Date().addingTimeInterval(-back) }
                _ = try? await friend.accept(CrewInvite(url: link))
                friend.now = Date.init
                // `-strataCrewFaces none`: nobody has a head or a photo, so
                // each friend is their own initial on their own colour (the
                // owner, 2026-10-13, of a capture where every friend wore
                // the one fixture head: "the pfp should be different for
                // each person").
                if argument("-strataCrewFaces") == "none" {
                    // Their initial stands for them.
                } else
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
                // Their score, as their phone would send it (`noteMyScore`).
                let wins = 6 + (f * 7 + c * 3) % 20
                friend.noteMyScore(WinsScore.Tally(score: wins * 2 - 1, wins: wins), settle: .zero)
                await friend.scoreSoon?.value
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
        // `-strataSeedInvited 1`: two people invited from contacts and not yet
        // in, one with a contact picture, one without.
        if argument("-strataSeedInvited") != nil, let crew = store.crews.first {
            let face = UIImage(named: "DemoPhoto8")?.jpegData(compressionQuality: 0.8)
                .flatMap { ShareDerivative.jpeg(from: $0, longEdge: 120) }
            InvitedPeople.shared.add(InvitedPerson(id: UUID(), name: "Maya Chen", photo: face,
                                                   crew: crew.id.rawValue, sentAt: Date()))
            InvitedPeople.shared.add(InvitedPerson(id: UUID(), name: "Jordan", photo: nil,
                                                   crew: crew.id.rawValue, sentAt: Date()))
        }
        // `-strataSeedStories <n>`: n friends on tonight's story, the first
        // with two wins (photos on every other); `-strataSeedMyStory 1` puts
        // one of yours on it too, `-strataStorySeen 1` has the last of them
        // watched. With `-strataStoryHour 21` they are open; without it,
        // before 8pm, they wait.
        if let n = argument("-strataSeedStories").flatMap(Int.init) {
            let lines = ["Finally finished the lab report", "Ran the whole loop without stopping", ""]
            for (k, friend) in friends.prefix(n).enumerated() {
                await friend.refresh()
                await friend.setStoryLine(lines[k % lines.count], on: CrewDay.string(for: Date(), in: .current))
                for j in 0..<(k == 0 ? 2 : 1) {
                    await friend.postStory(win(1 + k * 3 + j * 3, minutesAgo: 150 - k * 25 - j * 10))
                }
            }
            await store.refresh()
            if argument("-strataSeedMyStory") != nil { await store.postStory(win(7, minutesAgo: 40)) }
            if argument("-strataStorySeen") != nil, let last = friends.prefix(n).last {
                for story in store.storiesByCrew.values.flatMap({ $0 }) where story.sender == last.me {
                    store.markStorySeen(story.id)
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
        if let every = argument("-strataFriendSaysEvery").flatMap(Double.init) { startTalking(every: every) }
    }

    /// `-strataFriendSaysEvery <s>`: a friend's line in the first crew's
    /// chat every s seconds, as their phone would send it.
    private static func startTalking(every seconds: Double) {
        let lines = ["lunch at 1?", "just finished the run, legs are gone",
                     "who's up for a walk after work?", "6 works", "proud of everyone today"]
        Task { @MainActor in
            var i = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                guard let crew = SocialStore.shared.crews.first,
                      let friend = friends.first(where: { $0.crew(crew.id) != nil }) else { continue }
                friend.canReply = { true }
                await friend.refresh()
                await friend.send(lines[i % lines.count], in: crew.id)
                await SocialStore.shared.refresh()
                i += 1
            }
        }
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
        // A friend's win said in the chat (`sendWinLine`), to react to as
        // the win (2026-10-15).
        if let theirs = second.today(in: crew.id).last(where: { $0.senderProfileID == second.me && !$0.title.isEmpty }) {
            _ = await second.sendWinLine(theirs.winID, in: crew.id)
        }
        await second.send("6 works", in: crew.id)
        // `-strataSeedCrewStrip`: a friend's photo strip in the chat
        // (`CrewStripShare`), drawn the way their phone would send it.
        if argument("-strataSeedCrewStrip") != nil {
            let frames = ["DemoPhoto3", "DemoPhoto7", "DemoPhoto5"].enumerated().compactMap { i, name in
                UIImage(named: name).map { PhotoStrip.Frame(id: UUID(), title: ["Run", "Read", "Cooked"][i],
                                                            size: .medium, picture: $0) }
            }
            let renderer = ImageRenderer(content: StripView(frames: frames, day: DateUtils.dateString(from: Date()),
                                                            signature: "Sam", paper: .white,
                                                            width: StripStory.stripWidth).fixedSize())
            renderer.scale = 3 * CrewStripPicture.width / StripStory.stripWidth
            renderer.isOpaque = false
            if let png = renderer.uiImage?.pngData() {
                await first.refresh()
                await first.sendStrip(png, in: crew.id)
            }
        }
        if argument("-strataChatReact") != nil {
            await seedChatReactions(first: first, second: second, me: me, crew: crew.id)
        }
        // `-strataChatTail <kind>`: the chat's last lines a chosen way, for
        // the resting bar (the owner, 2026-10-15: "test the collapsed view
        // for when you text multiple times vs them texting multiple times
        // and various variations").
        if let tail = argument("-strataChatTail") {
            // Past the send pacing's quarter second since the seed's own
            // lines, as a person would be.
            try? await Task.sleep(for: .milliseconds(400))
            await seedChatTail(tail, first: first, second: second, me: me, crew: crew.id)
        }
        // `-strataSeedCrewPlan`: a friend plans something for today, another
        // friend does it (so the card can name who did), a sticker, and a
        // photo brought back with its line (`GroupPlan`, `ChatPlus`).
        if argument("-strataSeedCrewPlan") != nil {
            await second.refresh()
            _ = await second.sendPlan(title: "Evening walk", when: .day(CrewDay.string(for: Date(), in: crew.timeZone)), in: crew.id)
            await first.refresh()
            let now = Date()
            await first.post(OwnWin(winID: UUID(), title: "Evening walk", colour: .health, icon: .health, blockSize: .medium,
                                    photoJPEG: nil, cropX: nil, cropY: nil, createdAt: now, updatedAt: now), to: [crew.id])
            if let png = StickerMaker.sample()?.pngData() {
                await first.refresh()
                await first.sendSticker(png, in: crew.id)
            }
            if let photo = UIImage(named: "DemoPhoto5")?.jpegData(compressionQuality: 0.8) {
                await second.refresh()
                await second.sendPicture(photo, caption: "A year ago today.", in: crew.id)
            }
            await me.refresh()
        }
    }

    @MainActor
    private static func seedChatTail(_ kind: String, first: SocialStore, second: SocialStore, me: SocialStore,
                                     crew: CrewID) async {
        func say(_ who: SocialStore, _ words: String) async {
            await who.refresh()
            let outcome = await who.send(words, in: crew)
            NSLog("[strata-tail] %@ -> %@", words, String(describing: outcome))
            try? await Task.sleep(for: .milliseconds(300))
        }
        switch kind {
        case "mine3":
            await say(me, "on my way"); await say(me, "5 min"); await say(me, "actually 10, sorry")
        case "theirs3":
            await say(first, "where are you"); await say(first, "we're here"); await say(first, "by the door")
        case "mixed":
            await say(me, "running late"); await say(first, "all good"); await say(second, "same tbh"); await say(first, "take your time")
        case "long":
            await say(first, "okay so I finally finished the whole thing and honestly it took way longer than I thought it would but it's done")
        case "emoji":
            await say(first, "🔥🔥🔥")
        case "mineemoji":
            await say(me, "🙌")
        case "photo":
            if let photo = UIImage(named: "DemoPhoto7")?.jpegData(compressionQuality: 0.8) {
                await first.refresh(); _ = await first.sendPicture(photo, caption: "", in: crew)
            }
        case "minephoto":
            if let photo = UIImage(named: "DemoPhoto7")?.jpegData(compressionQuality: 0.8) {
                await me.refresh(); _ = await me.sendPicture(photo, caption: "view from the top", in: crew)
            }
        case "sticker":
            if let png = StickerMaker.sample()?.pngData() { await first.refresh(); _ = await first.sendSticker(png, in: crew) }
        case "strip":
            let frames = ["DemoPhoto3", "DemoPhoto7", "DemoPhoto5"].enumerated().compactMap { i, name in
                UIImage(named: name).map { PhotoStrip.Frame(id: UUID(), title: ["Run", "Read", "Cooked"][i],
                                                            size: .medium, picture: $0) }
            }
            let renderer = ImageRenderer(content: StripView(frames: frames, day: DateUtils.dateString(from: Date()),
                                                            signature: "Sam", paper: .white,
                                                            width: StripStory.stripWidth).fixedSize())
            renderer.scale = 3 * CrewStripPicture.width / StripStory.stripWidth
            renderer.isOpaque = false
            if let png = renderer.uiImage?.pngData() { await first.refresh(); _ = await first.sendStrip(png, in: crew) }
        case "winline":
            await second.refresh()
            if let theirs = second.today(in: crew).last(where: { $0.senderProfileID == second.me && !$0.title.isEmpty }) {
                _ = await second.sendWinLine(theirs.winID, in: crew)
            }
        case "minewinline":
            await me.refresh()
            if let mine = me.today(in: crew).last(where: { $0.senderProfileID == me.me && !$0.title.isEmpty }) {
                _ = await me.sendWinLine(mine.winID, in: crew)
            }
        case "doodle":
            if let png = StickerMaker.sample()?.pngData() { await first.refresh(); _ = await first.sendDoodle(png, in: crew) }
        case "theirsmixed":
            await say(first, "look at this")
            if let png = StickerMaker.sample()?.pngData() { await first.refresh(); _ = await first.sendSticker(png, in: crew) }
            try? await Task.sleep(for: .milliseconds(300))
            await say(first, "made it myself")
        case "plan":
            await second.refresh()
            _ = await second.sendPlan(title: "Evening walk", when: .day(CrewDay.string(for: Date(), in: me.crew(crew)?.timeZone ?? .current)), in: crew)
        default: break
        }
        await me.refresh()
    }

    /// Reactions on the seeded chat (2026-10-06): ❤️ from a friend and from
    /// you on the morning line, so a shared chip counts two with yours
    /// lifted; 🔥 and a friend's sticker under your own line; 🙌 on the walk.
    /// The sticker is the drawn sunflower `StickerMaker.sample` makes, since
    /// the subject lift does not run in the simulator; one is kept as yours
    /// too, so the bar has a sticker to offer.
    @MainActor
    private static func seedChatReactions(first: SocialStore, second: SocialStore, me: SocialStore,
                                          crew: CrewID) async {
        let sample = StickerMaker.sample()
        if StickerStore.shared.names.isEmpty, let sample { StickerStore.shared.add(sample) }
        for store in [first, second, me] { await store.refresh() }
        let lines = me.messages(in: crew)
        let morning = lines.first { $0.senderProfileID == first.me }
        let walk = lines.first { $0.senderProfileID == second.me }
        let mine = lines.first { $0.senderProfileID == me.me }
        if let morning {
            await second.react(.emoji("❤️"), toMessage: morning.messageID, in: crew)
            await me.react(.emoji("❤️"), toMessage: morning.messageID, in: crew)
        }
        if let mine {
            await first.react(.emoji("🔥"), toMessage: mine.messageID, in: crew)
            if let png = sample?.pngData() {
                await second.react(.sticker(name: "sticker-sample.png", png: png), toMessage: mine.messageID, in: crew)
            }
        }
        if let walk { await first.react(.emoji("🙌"), toMessage: walk.messageID, in: crew) }
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
        // Kept inside today, in the same order: just after midnight, wins
        // from "an hour ago" were yesterday's and every seeded tower came
        // up empty (2026-10-14, 00:05).
        let now = Date(), start = Calendar.current.startOfDay(for: now)
        let backdated = now.addingTimeInterval(-Double(minutesAgo) * 60)
        let date = backdated >= start ? backdated
            : start.addingTimeInterval(now.timeIntervalSince(start) / Double(2 + minutesAgo))
        let photo = i % 3 == 1 ? demoPhoto(1 + i % 12) : nil
        return OwnWin(winID: UUID(), title: title, colour: colour, icon: colour, blockSize: size,
                      photoJPEG: photo, cropX: nil, cropY: nil, createdAt: date, updatedAt: date)
    }
}
#endif
