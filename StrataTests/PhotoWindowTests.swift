import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Strata

/// Zooming a photo inside its frame (`PhotoWindow`, the owner's ask of
/// 2026-10-13: "you should be able to move the crop like zoom in that goes
/// for all the cropping").
@MainActor
@Suite("A photo zoomed in its frame")
struct PhotoWindowTests {
    private func code(_ path: String) throws -> String { SourceSweep.code(try SourceSweep.read(path)) }
    private let photo = CGSize(width: 1536, height: 2048)   // 3:4, as the camera keeps it
    private let block = CGSize(width: 300, height: 150)     // a wide block
    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Habit.self, HabitLog.self, MoodLog.self, Tower.self, PlanItem.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    // MARK: The window

    @Test("at one, a block draws exactly what it drew before there was a zoom")
    func oneIsToday() {
        // A 3:4 photo in a 300 by 150 block, its window moved a fifth down:
        // the numbers the app drew on 2026-10-12, worked by hand.
        let crop = CGPoint(x: 0, y: 0.2)
        #expect(CachedImageView.filled(photo, in: block) == CGSize(width: 300, height: 400))
        #expect(CachedImageView.shift(crop: crop, photo: photo, frame: block) == CGSize(width: 0, height: -80))
        let seen = CachedImageView.visibleRect(crop: crop, photo: photo, frame: block)
        #expect(seen.minX == 0 && abs(seen.minY - 0.5125) < 0.0001 && seen.width == 1 && abs(seen.height - 0.375) < 0.0001)
        #expect(CropEditor.range(photo: photo, frame: block) == CGSize(width: 0, height: 0.3125))
        // And asked for by name, one is the same.
        #expect(CachedImageView.shift(crop: crop, photo: photo, frame: block, zoom: 1) == CGSize(width: 0, height: -80))
    }

    @Test("a window is held inside its photo wherever it is drawn, not only in the editor")
    func heldWhereDrawn() {
        // Framed in a square, then drawn in a block twice as wide: the crop
        // is one the wide block cannot hold.
        let wide = CGSize(width: 4000, height: 3000), square = CGSize(width: 100, height: 100)
        let twoToOne = CGSize(width: 200, height: 100)
        let far = CGPoint(x: 0.125, y: 0)
        #expect(CachedImageView.shift(crop: far, photo: wide, frame: square).width < 0, "legal in the square")
        #expect(CachedImageView.shift(crop: far, photo: wide, frame: twoToOne).width == 0,
                "the wide block drew a bare band down one side")
        let seen = CachedImageView.visibleRect(crop: CGPoint(x: 9, y: -9), photo: wide, frame: twoToOne, zoom: 2)
        #expect(seen.minX > -0.0001 && seen.minY > -0.0001 && seen.maxX < 1.0001 && seen.maxY < 1.0001)
    }

    @Test("zoomed to two the block shows half as much each way, about the same middle")
    func zoomShowsLess() {
        let crop = CGPoint(x: 0.05, y: -0.1)
        let whole = CachedImageView.visibleRect(crop: crop, photo: photo, frame: block, zoom: 1)
        let half = CachedImageView.visibleRect(crop: crop, photo: photo, frame: block, zoom: 2)
        #expect(abs(half.width - whole.width / 2) < 0.0001)
        #expect(abs(half.height - whole.height / 2) < 0.0001)
        #expect(abs(half.midX - (0.5 + crop.x)) < 0.0001, "the window's middle is the crop, whatever the zoom")
        #expect(abs(half.midY - (0.5 + crop.y)) < 0.0001)
    }

    @Test("zoomed in there is further to move, and the window still never leaves the photo")
    func rangeGrows() {
        let one = CropEditor.range(photo: photo, frame: block, zoom: 1)
        let two = CropEditor.range(photo: photo, frame: block, zoom: 2)
        #expect(one.width == 0, "a wide block on a tall photo has no room sideways until it is zoomed")
        #expect(two.width > 0 && two.height > one.height)
        for zoom in [1, 1.5, 2, 3] as [CGFloat] {
            for far in [CGPoint(x: 9, y: 9), CGPoint(x: -9, y: -9), CGPoint(x: 9, y: -9)] {
                let held = CropEditor.clamped(far, photo: photo, frame: block, zoom: zoom)
                let seen = CachedImageView.visibleRect(crop: held, photo: photo, frame: block, zoom: zoom)
                #expect(seen.minX > -0.0001 && seen.minY > -0.0001 && seen.maxX < 1.0001 && seen.maxY < 1.0001,
                        "past the photo's edge at \(zoom): \(seen)")
            }
        }
    }

    @Test("the zoom is held between one and three, and nonsense is one")
    func held() {
        #expect(PhotoWindow.zoom(0.2) == 1)
        #expect(PhotoWindow.zoom(2.4) == 2.4)
        #expect(PhotoWindow.zoom(40) == PhotoWindow.maxZoom)
        #expect(PhotoWindow.zoom(.nan) == 1)
        #expect(PhotoWindow.maxZoom == 3)
    }

    // MARK: Where it is kept

    @Test("it rides in the dead XP field as a negative, so an old XP count is never a zoom")
    func stored() {
        #expect(PhotoWindow.stored(1) == nil, "a photo nobody pinched writes nothing")
        #expect(PhotoWindow.stored(2.5) == -2500)
        #expect(PhotoWindow.zoom(stored: -2500) == 2.5)
        #expect(PhotoWindow.zoom(stored: nil) == 1)
        // What the 2025 builds wrote there: counts of XP.
        for old in [0, 10, 250, 1500, 2500, 99_999] { #expect(PhotoWindow.zoom(stored: old) == 1, "\(old) read as a zoom") }
        #expect(PhotoWindow.zoom(stored: -900_000) == PhotoWindow.maxZoom)
    }

    @Test("a win keeps its zoom, and a win set back to one keeps nothing")
    func logKeepsIt() throws {
        let context = try context()
        let habit = Habit(title: "Walk", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-10-13", completed: true)
        context.insert(log)
        #expect(log.cropZoom == 1)
        log.cropZoom = 1.75
        #expect(log.pendingXP == -1750 && log.cropZoom == 1.75)
        log.cropZoom = 1
        #expect(log.pendingXP == nil)
    }

    @Test("a strip keeps each photo's zoom beside where it was moved, and still reads what it kept before")
    func stripKeepsIt() {
        let day = "test-\(UUID().uuidString)"
        let a = UUID(), b = UUID(), c = UUID()
        defer { UserDefaults.standard.removeObject(forKey: "strip.crop.\(PhotoStrip.Owner.me.key).\(day)") }
        StripKeeping.setCrops([a: CGPoint(x: 0.1, y: -0.05), b: .zero], zooms: [a: 2, c: 1.5], .me, day: day)
        #expect(StripKeeping.crops(.me, day: day)[a] == CGPoint(x: 0.1, y: -0.05))
        #expect(StripKeeping.zooms(.me, day: day) == [a: 2, c: 1.5])
        #expect(StripKeeping.crops(.me, day: day)[c] == .zero, "zoomed in the middle is kept: it is not nothing")
        #expect(StripKeeping.crops(.me, day: day)[b] == nil, "the middle of the whole photo is not kept")
        // As the builds before this one wrote it: two numbers, no zoom.
        UserDefaults.standard.set([a.uuidString: [0.2, 0.0]], forKey: "strip.crop.\(PhotoStrip.Owner.me.key).\(day)")
        #expect(StripKeeping.crops(.me, day: day)[a] == CGPoint(x: 0.2, y: 0))
        #expect(StripKeeping.zooms(.me, day: day).isEmpty)
    }

    // MARK: What a crew is sent

    @Test("a photo nobody zoomed is sent whole, exactly as before")
    func uncut() {
        #expect(PhotoWindow.cut(crop: CGPoint(x: 0.1, y: 0.2), zoom: 1) == nil)
    }

    @Test("a zoomed photo is cut so the crew's block shows the very window that was framed")
    func cutShowsTheSameWindow() {
        // A tall photo in a wide block, a wide photo in a tall one, a wide
        // photo in a square: each has room on a different axis.
        let shapes: [(CGSize, CGSize)] = [(photo, block),
                                          (CGSize(width: 2560, height: 1440), CGSize(width: 120, height: 300)),
                                          (CGSize(width: 2000, height: 1500), CGSize(width: 200, height: 200))]
        for (photo, block) in shapes { for zoom in [1.4, 2, 3] as [CGFloat] {
            for raw in [CGPoint.zero, CGPoint(x: 0.3, y: -0.3), CGPoint(x: -9, y: 9), CGPoint(x: 0.02, y: 0.4)] {
                let crop = CropEditor.clamped(raw, photo: photo, frame: block, zoom: zoom)
                let mine = CachedImageView.visibleRect(crop: crop, photo: photo, frame: block, zoom: zoom)
                guard let cut = PhotoWindow.cut(crop: crop, zoom: zoom) else { Issue.record("no cut at \(zoom)"); continue }
                #expect(cut.rect.minX > -0.0001 && cut.rect.minY > -0.0001
                        && cut.rect.maxX < 1.0001 && cut.rect.maxY < 1.0001, "the cut left the photo")
                // The friend's phone: the cut piece, filled into the same block, no zoom.
                let piece = CGSize(width: photo.width * cut.rect.width, height: photo.height * cut.rect.height)
                let theirs = CachedImageView.visibleRect(crop: cut.crop, photo: piece, frame: block)
                let onPhoto = CGRect(x: cut.rect.minX + theirs.minX * cut.rect.width,
                                     y: cut.rect.minY + theirs.minY * cut.rect.height,
                                     width: theirs.width * cut.rect.width, height: theirs.height * cut.rect.height)
                for (got, want) in [(onPhoto.minX, mine.minX), (onPhoto.minY, mine.minY),
                                    (onPhoto.width, mine.width), (onPhoto.height, mine.height)] {
                    #expect(abs(got - want) < 0.0005, "zoom \(zoom) crop \(crop): \(onPhoto) is not \(mine)")
                }
                // And what is left of the crop is one a whole photo could hold too.
                let range = CropEditor.range(photo: photo, frame: block)
                #expect(abs(cut.crop.x) <= range.width + 0.0001 && abs(cut.crop.y) <= range.height + 0.0001)
            }
        } }
    }

    /// The colour in the middle of a picture, read through a bitmap laid
    /// out red, green, blue, so nothing depends on how a JPEG decodes.
    private func middle(of data: Data) throws -> (size: CGSize, r: UInt8, g: UInt8, b: UInt8) {
        let image = try #require(UIImage(data: data)?.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // The picture's middle tenth, squeezed into the one pixel.
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let part = try #require(image.cropping(to: CGRect(x: w * 0.45, y: h * 0.45, width: w * 0.1, height: h * 0.1)))
        context.draw(part, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (CGSize(width: w, height: h), pixel[0], pixel[1], pixel[2])
    }

    @Test("the picture itself is cut: the right piece, the right size")
    func jpegIsCut() throws {
        // Four quarters, each its own colour: red, green over blue, white.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 400, height: 200)
        let picture = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
            UIColor.green.setFill(); context.fill(CGRect(x: 200, y: 0, width: 200, height: 100))
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 100, width: 200, height: 100))
            UIColor.white.setFill(); context.fill(CGRect(x: 200, y: 100, width: 200, height: 100))
        }
        let data = try #require(picture.jpegData(compressionQuality: 0.95))
        let topRight = try middle(of: try #require(PhotoWindow.jpeg(data, cutTo: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))))
        #expect(topRight.size == CGSize(width: 200, height: 100))
        #expect(topRight.g > 200 && topRight.r < 80 && topRight.b < 80, "the top right is green: \(topRight)")
        let bottomLeft = try middle(of: try #require(PhotoWindow.jpeg(data, cutTo: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5))))
        #expect(bottomLeft.b > 200 && bottomLeft.r < 80 && bottomLeft.g < 80, "the bottom left is blue: \(bottomLeft)")
        #expect(PhotoWindow.jpeg(Data([1, 2, 3]), cutTo: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)) == nil,
                "what cannot be read is not cut")
    }

    @Test("a zoomed win goes to a crew cut, keyed by its cut; an unzoomed one goes as it always did")
    func ownWinIsCut() throws {
        let context = try context()
        let habit = Habit(title: "Walk", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-10-13", completed: true)
        context.insert(log)
        log.imageFileName = "missing-\(UUID().uuidString).jpg"
        log.cropPositionX = 0.05
        let plain = try #require(CrewSync.ownWin(log))
        #expect(plain.photoCut == nil && plain.photoKey == log.imageFileName && plain.cropX == 0.05)

        log.cropZoom = 2
        let zoomed = try #require(CrewSync.ownWin(log))
        let cut = try #require(PhotoWindow.cut(crop: CGPoint(x: 0.05, y: 0), zoom: 2))
        #expect(zoomed.photoCut == cut.rect)
        #expect(zoomed.photoKey != plain.photoKey, "zooming did not send the photo again")
        // The window is in the middle of the piece here, and the middle is sent as nothing.
        #expect(cut.crop == .zero && zoomed.cropX == nil && zoomed.cropY == nil)
        log.cropPositionX = 0.4
        let edge = try #require(CrewSync.ownWin(log))
        let edgeCut = try #require(PhotoWindow.cut(crop: CGPoint(x: 0.4, y: 0), zoom: 2))
        #expect(edgeCut.crop.x != 0 && edge.cropX == Double(edgeCut.crop.x), "what is left of the crop at the photo's edge was not sent")
        log.cropPositionX = 0.2
        #expect(CrewSync.ownWin(log)?.photoKey != zoomed.photoKey, "moving a zoomed photo did not send it again")

        let store = try code("Strata/Social/SocialStore.swift")
        #expect(store.contains("derived(jpeg, cut: win.photoCut)"), "the cut is never applied to what is sent")
        #expect(store.contains("guard let piece = PhotoWindow.jpeg(jpeg, cutTo: cut) else { return nil }"),
                "a photo that cannot be cut is sent whole: more than its owner framed")
        // Nothing new goes into the record: a crew's copy has a crop and no zoom.
        #expect(!(try code("Strata/Social/CrewRecords.swift")).contains("photoCut"))
    }

    @Test("a doodle that replaced a photo is not sent the photo's crop")
    func doodleCarriesNoCrop() throws {
        let context = try context()
        let habit = Habit(title: "Sketch", category: .creativity)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "2026-10-13", completed: true)
        context.insert(log)
        log.doodleFileName = "missing-\(UUID().uuidString).ink"
        log.cropPositionX = 0.2
        log.cropZoom = 2
        let sent = try #require(CrewSync.ownWin(log))
        #expect(sent.cropX == nil && sent.cropY == nil && sent.photoCut == nil)
    }

    @Test("taking a photo off a win takes its window off too, on the win and on that day's strips")
    func removalClearsTheWindow() throws {
        let context = try context()
        let habit = Habit(title: "Walk", category: .health)
        context.insert(habit)
        let log = HabitLog(habit: habit, dateString: "test-\(UUID().uuidString)", completed: true)
        context.insert(log)
        let name = "missing-\(UUID().uuidString).jpg"
        log.imageFileName = name
        log.cropPositionX = 0.1
        log.cropPositionY = -0.2
        log.cropZoom = 2.5
        let other = UUID()
        for owner in [PhotoStrip.Owner.me, .crew("test")] {
            StripKeeping.setCrops([log.id: CGPoint(x: 0.1, y: 0), other: CGPoint(x: 0.2, y: 0)],
                                  zooms: [log.id: 2], owner, day: log.dateString)
        }
        defer {
            for owner in [PhotoStrip.Owner.me, .crew("test")] {
                UserDefaults.standard.removeObject(forKey: "strip.crop.\(owner.key).\(log.dateString)")
            }
        }
        try context.save()
        PhotoRemoval.removePhoto(fileName: name, context: context)
        #expect(log.imageFileName == nil)
        #expect(log.cropPositionX == nil && log.cropPositionY == nil && log.cropZoom == 1 && log.pendingXP == nil)
        for owner in [PhotoStrip.Owner.me, .crew("test")] {
            #expect(StripKeeping.crops(owner, day: log.dateString)[log.id] == nil)
            #expect(StripKeeping.zooms(owner, day: log.dateString)[log.id] == nil)
            #expect(StripKeeping.crops(owner, day: log.dateString)[other] == CGPoint(x: 0.2, y: 0), "another win's window went too")
        }
    }

    @Test("a replay decodes a zoomed block's photo larger, and never past the file")
    func replayDecodesMore() {
        #expect(ReplayImages.decodeSide(cellPixels: 267, span: 1, zoom: 1) == 356)
        #expect(ReplayImages.decodeSide(cellPixels: 267, span: 1, zoom: 3) == 1068)
        #expect(ReplayImages.decodeSide(cellPixels: 800, span: 2, zoom: 3) == ImageManager.storedMaxDimension)
    }

    // MARK: Drawn everywhere

    @Test("every place a win's photo is drawn in a block is given its zoom")
    func wired() throws {
        let add = try code("Strata/Views/AddWinSheet.swift")
        #expect(add.contains("zoom = CGFloat(log.cropZoom)"), "a win being edited opens on the middle again")
        #expect(add.contains("if !photoChanged, photo != nil, log.imageFileName != nil { writeWindow(to: log) }"),
                "Move Photo on a win already logged saves nothing")
        #expect(add.contains("CachedImageView.filled(photo.size, in: well, zoom: zoom)"))
        #expect(add.components(separatedBy: "cropAspect = w / max(h, 1)").count == 3,
                "Move Photo from a press on the block opens in the last shape a long press left")
        // The window is written once the new file is named, never before the write is awaited.
        let attach = try #require(add.range(of: "private func attach(_ image: UIImage, to log: HabitLog) async -> Bool"))
        let saved = try #require(add.range(of: "ImageManager.shared.save(image: image, for: id)", range: attach.upperBound..<add.endIndex))
        #expect(add.range(of: "writeWindow(to: log)", range: attach.upperBound..<saved.lowerBound) == nil,
                "for as long as the write takes, the log names the old photo with the new one's window")
        #expect(add.range(of: "writeWindow(to: log)", range: saved.upperBound..<add.endIndex) != nil)
        #expect(try code("Strata/Views/FlippableBlockView.swift").contains("zoom: CGFloat(block.look.cropZoom)"))
        #expect(try code("Strata/ViewModels/TowerViewModel.swift").contains("cropZoom = log.cropZoom"))
        #expect(try code("Strata/Models/Replay.swift").contains("zoom: CGFloat(log.cropZoom)"))
        #expect(try code("Strata/Views/ReplayFrame.swift").contains("photo(image, crop: block.win.crop, zoom: block.win.zoom"))
        #expect(try code("Strata/Views/Strip/StripView.swift").contains("CachedImageView.filled(frame.picture.size, in: size, zoom: frame.zoom)"))
        #expect(try code("Strata/Services/BackupExport.swift").contains("cropZoom: log.cropZoom > 1 ? log.cropZoom : nil"))
        #expect(try code("Strata/Services/BackupRestore.swift").contains("log.cropZoom = exported.cropZoom ?? 1"))
        let view = try code("Strata/Views/CachedImageView.swift")
        #expect(view.contains(".scaleEffect(PhotoWindow.zoom(zoom))"))
        #expect(view.contains("(decodeWidth ?? width) * displayScale * PhotoWindow.zoom(zoom)"),
                "a zoomed block is drawn from a thumbnail the size of the block")
    }

    @Test("the box: dimmed outside by 45%, thirds at 25%, corners in his pen")
    func box() throws {
        #expect(CropBox.dim == 0.45 && CropBox.grid == 0.25)
        let source = try code("Strata/Views/CropBox.swift")
        #expect(source.contains("lineWidth: InkPen.width, lineCap: .round, lineJoin: .round"))
        // Four marks, none of them a closed box, each inside its own corner.
        let rect = CGRect(x: 0, y: 0, width: 200, height: 120)
        let path = SketchCorners(radius: 12).path(in: rect)
        var starts = 0
        path.forEach { if case .move = $0 { starts += 1 } }
        #expect(starts == 4)
        let arm = SketchCorners.arm(in: rect, radius: 12)
        #expect(arm > 0 && 12 + arm < rect.height / 2, "two corners' marks met along the short side")
        #expect(path.boundingRect.insetBy(dx: -2, dy: -2).contains(rect.insetBy(dx: 2, dy: 2)) == true)
        let editor = try code("Strata/Views/CropEditor.swift")
        #expect(editor.contains("MagnifyGesture()") && editor.contains("onDone(Self.clamped(crop, photo: image.size, frame: CGSize(width: aspect, height: 1), zoom: zoom)"))
        #expect(editor.contains("accessibilityAdjustableAction"), "no way to zoom without a pinch")
    }
}
