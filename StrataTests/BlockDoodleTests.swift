import Testing
import Foundation
import PencilKit
import SwiftData
import UIKit
@testable import Strata

/// **A doodle on the block** (the owner, 2026-10-06: "should we add doodling
/// on the colored blocks like when you are adding a win alternative to adding
/// a picture"; his picks, "Photo or doodle" and "White ink").
@MainActor
@Suite("A doodle on the block", .serialized)
struct BlockDoodleTests {
    private let canvas = CGSize(width: 370, height: 370)

    private func container() throws -> ModelContainer {
        try ModelContainer(for: Habit.self, HabitLog.self, Tower.self, MoodLog.self, PlanItem.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test("a doodle is written, read back to edit, and replaced without leaving files")
    func roundTrip() throws {
        let files = InkTests.folder()
        let first = try #require(BlockDoodles.save(InkTests.drawing(strokes: [60, 30]), canvas: canvas,
                                                   replacing: nil, files: files))
        #expect(files.exists(first))
        #expect(files.exists(BlockDoodles.drawingName(for: first)))
        let kept = try #require(BlockDoodles.drawing(for: first, files: files))
        #expect(kept.drawing.strokes.count == 2)
        #expect(kept.canvas == canvas, "the canvas comes back, so Edit can scale it")

        let second = try #require(BlockDoodles.save(InkTests.drawing(strokes: [20]), canvas: canvas,
                                                    replacing: first, files: files))
        #expect(second != first)
        #expect(!files.exists(first), "the old picture was left behind")
        #expect(!files.exists(BlockDoodles.drawingName(for: first)))

        // Rubbed out is no doodle, and takes the old one with it.
        #expect(BlockDoodles.save(PKDrawing(), canvas: canvas, replacing: second, files: files) == nil)
        #expect(!files.exists(second))
    }

    @Test("the name lives in a dead column, so no CloudKit schema change")
    func deadColumn() throws {
        let container = try container()
        let win = try QuickWinService.logWin(title: "Swim", category: .health, size: .small,
                                             context: container.mainContext, tower: nil)
        let log = try #require((win.habit.logs ?? []).first)
        log.doodleFileName = "doodle-1.png"
        #expect(log.imageURL == "doodle-1.png")
        log.doodleFileName = ""
        #expect(log.imageURL == nil && log.doodleFileName == nil)
    }

    @Test("a block draws its doodle only when it has no photograph")
    func photoOrDoodle() throws {
        let container = try container()
        let win = try QuickWinService.logWin(title: "Swim", category: .health, size: .small,
                                             context: container.mainContext, tower: nil)
        let log = try #require((win.habit.logs ?? []).first)
        log.doodleFileName = "doodle-1.png"
        #expect(PlacedBlock.Look(habit: win.habit, log: log).doodleFileName == "doodle-1.png")
        log.imageFileName = "photo-1.heic"
        #expect(PlacedBlock.Look(habit: win.habit, log: log).doodleFileName == nil)
    }

    @Test("undo after a delete brings the doodle back")
    func undoKeepsTheDoodle() throws {
        let container = try container()
        let context = container.mainContext
        let win = try QuickWinService.logWin(title: "Swim", category: .health, size: .small,
                                             context: context, tower: nil)
        try #require((win.habit.logs ?? []).first).doodleFileName = "doodle-1.png"
        try context.save()
        let pending = try WinDeletion.delete(win.habit, in: context)
        pending.undo()
        let back = try context.fetch(FetchDescriptor<Habit>())
        #expect(back.first?.logs?.first?.doodleFileName == "doodle-1.png")
    }

    @Test("the Add sheet keeps a block to one or the other, and draws in white")
    func addSheetWiring() throws {
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/AddWinSheet.swift"))
        #expect(sheet.contains("doodleTile(well)"), "the pen beside the block is gone")
        #expect(sheet.contains("Button(\"Doodle\") { doodling = true }"))
        // A photograph put on takes the doodle off, and a doodle the photo.
        #expect(sheet.contains("if now != nil, doodle != nil {"))
        let keep = try #require(sheet.components(separatedBy: "private func keepDoodle").dropFirst().first)
        #expect(keep.components(separatedBy: "private var").first?.contains("photo = nil") == true)
        let editor = SourceSweep.code(try SourceSweep.read("Strata/Views/Ink/BlockDoodleSheet.swift"))
        #expect(editor.contains("lightInk: true"))
        // Warm white since the owner's "Warm ink" (2026-10-06), not pure white.
        #expect(editor.contains(".foregroundStyle(AppColors.drawingInkOnBlock)"))
        #expect(editor.contains("InkPen.blockWidth(onCanvasOfHeight:"))
    }

    /// The owner, 2026-10-06: "make doodles show on crew tower and replays
    /// too". A friend's phone draws a crew win from its photograph, so a
    /// doodle is sent as one: the colour with the white ink on it.
    @Test("a crew gets the doodled block as one picture: its colour, the ink white")
    func crewPicture() throws {
        let files = InkTests.folder()
        // One thick stroke across the middle of a 300 by 300 canvas.
        let name = try #require(BlockDoodles.save(InkTests.drawing(strokes: [260], width: 20),
                                                  canvas: CGSize(width: 300, height: 300),
                                                  replacing: nil, files: files))
        let data = try #require(BlockDoodles.crewPicture(name, colour: .health, files: files))
        let picture = try #require(UIImage(data: data)?.cgImage)
        #expect(picture.width == 600 && picture.height == 600, "the block's shape at 2x")
        var bytes = [UInt8](repeating: 0, count: picture.width * picture.height * 4)
        let context = try #require(CGContext(data: &bytes, width: picture.width, height: picture.height,
                                             bitsPerComponent: 8, bytesPerRow: picture.width * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(picture, in: CGRect(x: 0, y: 0, width: picture.width, height: picture.height))
        // Somewhere is white ink, and the bottom corner is the block's colour.
        var white = 0
        for i in stride(from: 0, to: bytes.count, by: 4) where bytes[i] > 240 && bytes[i + 1] > 240 && bytes[i + 2] > 240 {
            white += 1
        }
        #expect(white > 500, "no white ink in the picture")
        let corner = 4 * (picture.width * 5 + 5)
        #expect(!(bytes[corner] > 240 && bytes[corner + 1] > 240 && bytes[corner + 2] > 240),
                "the ground is white, not the block's colour")
    }

    @Test("crews and replays are handed the doodle")
    func crewsAndReplays() throws {
        let sync = SourceSweep.code(try SourceSweep.read("Strata/Social/CrewSync.swift"))
        #expect(sync.contains("BlockDoodles.crewPicture($0, colour: habit.displayCategory)"))
        let replay = SourceSweep.code(try SourceSweep.read("Strata/Models/Replay.swift"))
        #expect(replay.contains("doodle: log.imageFileName == nil ? log.doodleFileName : nil"))
        let frame = SourceSweep.code(try SourceSweep.read("Strata/Views/ReplayFrame.swift"))
        #expect(frame.contains("doodle: block.win.doodle"))
    }
}
