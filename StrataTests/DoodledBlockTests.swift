import Testing
import Foundation
import PencilKit
import SwiftData
import UIKit
@testable import Strata

/// **A doodled block is its own block, everywhere** (the owner, 2026-10-06:
/// "colors still merge even when there is a doodle on the block ... Make sure
/// the doodles aren't just like a quick feature, like they should count in
/// the photo strip, count as their own block and all that, and work well in
/// crew").
@MainActor
@Suite("A doodled block", .serialized)
struct DoodledBlockTests {
    private let canvas = CGSize(width: 300, height: 300)

    private func container() throws -> ModelContainer {
        try ModelContainer(for: Habit.self, HabitLog.self, Tower.self, MoodLog.self, PlanItem.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// Four small green wins, which pack side by side along the bottom row.
    private func fourGreen(in context: ModelContext) throws -> [HabitLog] {
        try (0..<4).map { i in
            let win = try QuickWinService.logWin(title: "Swim \(i)", category: .health, size: .small,
                                                 context: context, tower: nil)
            return try #require((win.habit.logs ?? []).first)
        }
    }

    @Test("a doodled block never joins its same-colour neighbours, and joins again once the doodle is off")
    func doodleStandsAlone() throws {
        let container = try container()
        let logs = try fourGreen(in: container.mainContext)
        let vm = TowerViewModel()

        vm.buildTower(from: logs)
        #expect(vm.placedBlocks.allSatisfy { $0.row == 0 }, "the fixture is one row of four")
        #expect(vm.mergeGroups.count == 1)
        #expect(vm.groupedBlockIDs == Set(logs.map(\.id)), "four plain greens are one run")

        let doodled = logs[1]
        doodled.doodleFileName = "doodle-test.png"
        vm.buildTower(from: logs)
        #expect(!vm.groupedBlockIDs.contains(doodled.id),
                "the doodled block was folded into the run, which draws over its doodle")
        #expect(vm.mergeGroups.allSatisfy { !$0.memberIDs.contains(doodled.id) })
        // Its left neighbour is now alone; the two on its right are a run.
        #expect(vm.groupedBlockIDs == [logs[2].id, logs[3].id])

        doodled.doodleFileName = nil
        vm.buildTower(from: logs)
        #expect(vm.groupedBlockIDs == Set(logs.map(\.id)), "rubbed out, it is plain colour and joins again")
    }

    @Test("a photograph and a doodle both stand alone; a plain block does not")
    func standsAlone() throws {
        let container = try container()
        let log = try #require(try fourGreen(in: container.mainContext).first)
        let habit = try #require(log.habit)
        #expect(!PlacedBlock.Look(habit: habit, log: log).standsAlone)
        log.doodleFileName = "doodle-test.png"
        #expect(PlacedBlock.Look(habit: habit, log: log).standsAlone)
        log.doodleFileName = nil
        log.imageFileName = "photo.heic"
        #expect(PlacedBlock.Look(habit: habit, log: log).standsAlone)
    }

    @Test("the strip takes a doodled win, and lets it go once the doodle is off")
    func stripTakesTheDoodle() async throws {
        let container = try container()
        let context = container.mainContext
        let files = InkTests.folder()
        let logs = try fourGreen(in: context)
        let doodled = logs[2]
        doodled.doodleFileName = BlockDoodles.save(InkSamples.sunOverHill(in: canvas), canvas: canvas,
                                                   replacing: nil, files: files)
        try #require(doodled.doodleFileName != nil)
        try context.save()

        let strip = await PhotoStrip.mine(day: doodled.dateString, context: context, files: files)
        #expect(strip.candidates.map(\.id) == [doodled.id], "only the doodled win has a picture")
        let frame = try #require(strip.candidates.first)
        #expect(frame.picture.size.width > 0)
        // The picture is the block's colour with the ink on it, not a blank.
        #expect(Self.hasTwoTones(frame.picture), "the strip frame did not carry the doodle")

        let name = try #require(doodled.doodleFileName)
        BlockDoodles.remove(name, files: files)
        doodled.doodleFileName = nil
        try context.save()
        let after = await PhotoStrip.mine(day: doodled.dateString, context: context, files: files)
        #expect(after.candidates.isEmpty, "a win whose doodle was taken off stayed on the strip")
    }

    @Test("a crew is sent the doodle, and nothing once it is taken off")
    func crewIsSentTheDoodle() throws {
        let container = try container()
        let context = container.mainContext
        let log = try #require(try fourGreen(in: context).first)
        // `ownWin` reads the phone's own ink folder, as the app does.
        let name = try #require(BlockDoodles.save(InkSamples.sunOverHill(in: canvas), canvas: canvas,
                                                  replacing: nil))
        defer { BlockDoodles.remove(name) }
        log.doodleFileName = name

        let sent = try #require(CrewSync.ownWin(log))
        #expect(sent.photoJPEG != nil, "a doodled win went to the crew as a plain block")
        #expect(sent.photoKey?.hasPrefix(name) == true)

        log.doodleFileName = nil
        let undoodled = try #require(CrewSync.ownWin(log))
        #expect(undoodled.photoJPEG == nil)
        #expect(undoodled.photoKey == nil, "the key must change, or the removal is never sent")
    }

    /// Whether an image has both a dark and a light pixel along its middle
    /// row: the block's colour and the white ink.
    private static func hasTwoTones(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var light = false, dark = false
        for y in stride(from: 0, to: h, by: max(h / 40, 1)) {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let lum = (Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])) / 3
                if lum > 235 { light = true }
                if lum < 200 { dark = true }
            }
        }
        return light && dark
    }
}

/// **The crew's copy of a doodle is a new file each time it changes**, so
/// your own crew tower shows the redraw instead of the cached old picture.
@MainActor
@Suite("A doodled block in a crew", .serialized)
struct DoodledCrewBlockTests {
    let world = FakeCrewWorld()
    let jayden = UUID()

    private func store() -> SocialStore {
        let suite = "doodle-crew-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let dir = FileManager.default.temporaryDirectory.appending(path: suite, directoryHint: .isDirectory)
        let store = SocialStore(cloud: FakeCrewCloud(world: world, me: jayden), defaults: defaults, directory: dir)
        store.isEnabled = { true }
        store.myFirstName = { "Jayden" }
        store.derive = { $0 }
        return store
    }

    private func win(_ id: UUID, picture: Data?, key: String?) -> OwnWin {
        var win = OwnWin(winID: id, title: "", colour: .health, icon: .health, blockSize: .small,
                         photoJPEG: picture, cropX: nil, cropY: nil, createdAt: .now, updatedAt: .now)
        win.photoKey = key
        return win
    }

    @Test("a redrawn doodle is a new file, the old one goes, and taking it off clears it")
    func redrawIsANewFile() async throws {
        let a = store()
        let (crew, _) = try await a.createCrew(name: "One")
        let id = UUID()
        await a.post(win(id, picture: Data([0xFF, 0xD8, 0x01]), key: "doodle-a.png-health"), to: [crew.id])
        let first = try #require(a.wins(in: crew.id).first?.photo)
        #expect(FileManager.default.fileExists(atPath: first.path))

        await a.update(win(id, picture: Data([0xFF, 0xD8, 0x02]), key: "doodle-b.png-health"))
        let second = try #require(a.wins(in: crew.id).first?.photo)
        #expect(second != first, "the redraw landed on the URL the crew block was already showing")
        #expect(FileManager.default.fileExists(atPath: second.path))
        #expect(!FileManager.default.fileExists(atPath: first.path), "the old doodle was left on disk")
        #expect(try Data(contentsOf: second) == Data([0xFF, 0xD8, 0x02]))

        await a.update(win(id, picture: nil, key: nil))
        #expect(a.wins(in: crew.id).first?.photo == nil)
        #expect(world.records(of: .sharedWin, in: crew.id).values.first?["photo"] == nil)
        #expect(!FileManager.default.fileExists(atPath: second.path))
    }
}
