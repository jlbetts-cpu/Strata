import CoreImage
import Testing
import Foundation
import UIKit
@testable import Strata

/// **Your own stickers** (the owner, 2026-10-06: "personal stickers you can
/// use as reactions sticking on your journal and calendar"; his pick, "From
/// your photos", crew reactions later).
@MainActor
@Suite("Stickers", .serialized)
struct StickerTests {
    private func store() -> StickerStore {
        StickerStore(directory: FileManager.default.temporaryDirectory
            .appending(path: "stickers-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    private func square(_ colour: UIColor, side: CGFloat = 40) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            colour.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    @Test("a sticker stands in the day's emoji slot, and an emoji is still an emoji")
    func symbolSlot() {
        let symbol = StickerStore.symbol(for: "sticker-1.png")
        #expect(StickerStore.name(in: symbol) == "sticker-1.png")
        #expect(StickerStore.name(in: "🌻") == nil)
        #expect(StickerStore.name(in: "sticker:") == nil)
        #expect(JournalMark.forDay(symbol: symbol, written: false) == .sticker("sticker-1.png"))
        #expect(JournalMark.forDay(symbol: "🌻", written: false) == .emoji("🌻"))
        #expect(JournalMark.spoken(symbol) == "a sticker", "VoiceOver read the file name")
        #expect(JournalMark.spoken("🌻") == "🌻")
    }

    @Test("stickers are kept newest first, read back, and removed from the picker but not from what wears them")
    func kept() throws {
        let store = store()
        let first = try #require(store.add(square(.red)))
        let second = try #require(store.add(square(.blue)))
        #expect(store.names == [second, first])
        #expect(store.image(first) != nil)
        // A fresh store reads the index from disk.
        #expect(StickerStore(directory: store.directory).names == [second, first])
        store.remove(first)
        #expect(store.names == [second])
        // Changed 2026-10-08: deleting the file left every day, sketch and
        // strip that wore it with a gap. Out of the picker, still drawn.
        #expect(store.image(first) != nil, "a removed sticker still draws where it was placed")
        #expect(StickerStore(directory: store.directory).names == [second], "and stays out of the picker")
    }

    @Test("the oldest goes when the limit is passed")
    func limit() {
        let store = store()
        for _ in 0..<(StickerStore.limit + 2) { store.add(square(.green, side: 4)) }
        #expect(store.names.count == StickerStore.limit)
    }

    @Test("the rim is white, outside the subject, and never clipped")
    func rim() throws {
        // A red square standing in for a lifted subject.
        let subject = CIImage(cgImage: try #require(square(.red, side: 100).cgImage))
        let sticker = try #require(StickerMaker.outlined(subject))
        let cg = try #require(sticker.cgImage)
        #expect(cg.width > 100 && cg.height > 100, "no room was made for the rim")
        let pixel = { (x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) in
            var bytes = [UInt8](repeating: 0, count: 4)
            let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
            return (bytes[0], bytes[1], bytes[2], bytes[3])
        }
        let w = cg.width, h = cg.height
        #expect(pixel(0, 0).a == 0, "the corner should be clear")
        let centre = pixel(w / 2, h / 2)
        #expect(centre.r > 200 && centre.g < 60, "the subject is under the rim")
        // Just outside the subject, on the rim: white and solid.
        let pad = (w - 100) / 2
        let rim = pixel(w / 2, pad - 3)
        #expect(rim.a > 240 && rim.r > 240 && rim.g > 240 && rim.b > 240, "the rim is not white: \(rim)")
    }

    @Test("the journal's corner opens the sticker picker, and the calendar draws stickers")
    func wiring() throws {
        let sheet = SourceSweep.code(try SourceSweep.read("Strata/Views/DaySheet.swift"))
        #expect(sheet.contains("StickerPicker(current: symbol"))
        // Emoji is still one tap from the picker, and the same mark again
        // still takes it off.
        #expect(sheet.contains("symbol = picked == symbol ? nil : picked"))
        let calendar = SourceSweep.code(try SourceSweep.read("Strata/Views/MonthCalendarView.swift"))
        #expect(calendar.contains("case .sticker(let name):"))
        #expect(calendar.contains("JournalMark.spoken($0)"))
    }

    /// The owner, 2026-10-06: "new sticker button crashes". The photo picker
    /// was presented from inside the sticker popover: nothing on the
    /// simulator, a crash on a phone. The host closes the popover and opens
    /// the photos itself, as Emoji already did.
    @Test("New Sticker opens the photos from the host, never from inside the popover")
    func newStickerFromTheHost() throws {
        let picker = SourceSweep.code(try SourceSweep.read("Strata/Views/StickerPicker.swift"))
        let inside = try #require(picker.components(separatedBy: "struct StickerMaking").first)
        #expect(!inside.contains(".photosPicker("), "the popover must not present the photo picker")
        for host in ["Strata/Views/DaySheet.swift", "Strata/Views/Ink/InkCanvas.swift"] {
            let code = SourceSweep.code(try SourceSweep.read(host))
            #expect(code.contains("onNewSticker: {"), "\(host)")
            #expect(code.contains(".stickerMaking(isPresented: $choosingPhoto)"), "\(host)")
        }
    }
}
