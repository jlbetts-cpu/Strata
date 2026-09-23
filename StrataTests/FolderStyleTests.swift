import Testing
import SwiftUI
import UIKit
@testable import Strata

/// **The folder palette, and the day that is dealt one.**
///
/// Two claims are made in prose about this and neither is self-evident, so
/// both are pinned here: that the colours are calm rather than neon, and that
/// a day's colour is stable and never repeats yesterday's.
@MainActor
@Suite("Folder colours and dressing")
struct FolderStyleTests {

    private func hsb(_ colour: Color) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(colour).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    /// The owner: "make sure the random colours still fit the vibe and aren't
    /// like neon or anything like that, like very comforting chill colours."
    ///
    /// The constraint lives in the palette rather than in the draw, so this
    /// is where it can be checked. **It can fail**: raising any entry past
    /// 0.34 saturation, or dropping one below 0.06, trips it — and the second
    /// half matters as much as the first, because a colour with no chroma in
    /// it reads as a folder that is switched off. That is exactly how "Ink"
    /// was caught.
    @Test("Every folder colour is muted, and none of them is a grey")
    func paletteIsCalm() {
        for tint in FolderTint.all {
            let c = hsb(tint.colour)
            #expect(c.s <= 0.34, "\(tint.name) is at \(c.s) saturation, which is not calm")
            #expect(c.s >= 0.06, "\(tint.name) has no colour in it at \(c.s)")
            // Bright enough to be an object on a warm white page, short of
            // being a light source on it.
            #expect(c.b >= 0.55 && c.b <= 0.95,
                    "\(tint.name) is at \(c.b) brightness, which is not a surface")
        }
    }

    @Test("The palette has no two entries the same")
    func paletteIsDistinct() {
        let ids = Set(FolderTint.all.map(\.id))
        #expect(ids.count == FolderTint.all.count)
        let colours = Set(FolderTint.all.map { UIColor($0.colour).description })
        #expect(colours.count == FolderTint.all.count)
    }

    /// A folder that changed colour between launches would be the worst thing
    /// this could do, so the draw is a hash rather than a random number.
    @Test("A day is dealt the same colour every time it is asked")
    func seedIsStable() {
        for day in ["2026-09-22", "2026-01-01", "2025-12-31", "2026-06-15"] {
            let first = FolderTint.seeded(for: day)
            for _ in 0..<50 {
                #expect(FolderTint.seeded(for: day).id == first.id)
            }
        }
    }

    /// One pair in six would otherwise come up as two identical folders side
    /// by side, which does not read as random, it reads as a bug.
    @Test("No day is dealt the colour the day before it got")
    func neighboursDiffer() throws {
        let calendar = Calendar.current
        var day = try #require(DateUtils.date(from: "2026-01-01"))
        for _ in 0..<400 {
            let key = DateUtils.dateString(from: day)
            let before = try #require(calendar.date(byAdding: .day, value: -1, to: day))
            let earlierKey = DateUtils.dateString(from: before)
            #expect(FolderTint.seeded(for: key).id != FolderTint.seeded(for: earlierKey).id,
                    "\(key) and \(earlierKey) were dealt the same colour")
            day = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        }
    }

    /// Over a year the draw should touch every colour rather than favouring
    /// one. Not a claim about uniformity — a hash is not a generator — only
    /// that nothing is unreachable.
    @Test("A year uses the whole palette")
    func seedSpreads() throws {
        var seen: Set<String> = []
        var day = try #require(DateUtils.date(from: "2026-01-01"))
        for _ in 0..<365 {
            seen.insert(FolderTint.seeded(for: DateUtils.dateString(from: day)).id)
            day = try #require(Calendar.current.date(byAdding: .day, value: 1, to: day))
        }
        #expect(seen.count == FolderTint.all.count, "only \(seen.count) colours were ever dealt")
    }

    // MARK: - The store

    private func store() -> FolderStyleStore {
        let defaults = UserDefaults(suiteName: "folder-style-\(UUID().uuidString)")!
        return FolderStyleStore(defaults: defaults)
    }

    @Test("A folder nobody has dressed takes the colour its day was dealt")
    func defaultIsTheDealtColour() {
        let key = "2026-09-22"
        let style = store().style(for: key)
        #expect(style.tintID.isEmpty)
        #expect(style.faceName == nil, "a face is off by default")
        #expect(UIColor(style.tint(for: key)) == UIColor(FolderTint.seeded(for: key).colour))
    }

    @Test("A colour and a face survive being written and read back")
    func dressingRoundTrips() {
        let defaults = UserDefaults(suiteName: "folder-style-\(UUID().uuidString)")!
        let key = "2026-09-20"
        var style = FolderStyle()
        style.tintID = FolderTint.slate.id
        style.faceName = "Delighted"
        FolderStyleStore(defaults: defaults).set(style, for: key)

        // A second store over the same defaults is the next launch.
        let reopened = FolderStyleStore(defaults: defaults).style(for: key)
        #expect(reopened.tintID == FolderTint.slate.id)
        #expect(reopened.faceName == "Delighted")
        #expect(UIColor(reopened.tint(for: key)) == UIColor(FolderTint.slate.colour))
    }

    /// The store only ever holds choices somebody actually made, so putting a
    /// folder back to automatic has to leave nothing behind.
    @Test("Setting a folder back to the default keeps no row")
    func defaultKeepsNoRow() {
        let s = store()
        var style = FolderStyle()
        style.tintID = FolderTint.plum.id
        s.set(style, for: "2026-09-19")
        #expect(s.styles.count == 1)
        s.set(FolderStyle(), for: "2026-09-19")
        #expect(s.styles.isEmpty, "a folder put back to automatic left a row behind")
    }

    @Test("Pruning drops the days that are no longer reachable and keeps the rest")
    func pruneBounds() {
        let s = store()
        var style = FolderStyle()
        style.tintID = FolderTint.clay.id
        for key in ["2025-01-01", "2026-09-01", "2026-09-22"] {
            s.set(style, for: key)
        }
        s.prune(before: "2026-09-02")
        #expect(s.styles.keys.sorted() == ["2026-09-22"])
    }

    @Test("The cutoff is the keep window behind the day it is given")
    func cutoffIsAWindowBack() throws {
        let today = try #require(DateUtils.date(from: "2026-09-22"))
        let cutoff = try #require(DateUtils.date(from: FolderStyleStore.cutoff(from: today)))
        let days = Calendar.current.dateComponents([.day], from: cutoff, to: today).day
        #expect(days == 120)
    }
}
