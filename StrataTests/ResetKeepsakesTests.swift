import Testing
import Foundation
@testable import Strata

/// **Reset All Data takes what lives beside the record** (2026-10-08).
///
/// Self-test: drop the ink loop in `StoreReset.removeKeepsakes` and
/// `inkAndKeysGo` fails with every sketch still on disk; widen
/// `keepsakeKeys` to `tips.` and `theTipStays` fails.
@Suite("Reset keepsakes", .serialized)
@MainActor
struct ResetKeepsakesTests {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reset-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func defaults() -> (UserDefaults, String) {
        let name = "reset-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return (d, name)
    }

    @Test("ink files, strip keys, tip-ask counters and the analytics id go")
    func inkAndKeysGo() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ink = InkFiles(directory: dir)
        for name in ["sketch-1.png", "doodle-2.png", "month-2026-10.json", "strip-me-2026-10-08.png"] {
            try ink.write(Data([1, 2, 3]), named: name)
        }
        // A folder is never taken, whatever is in the ink folder.
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("kept"), withIntermediateDirectories: true)
        let (d, name) = defaults()
        defer { d.removePersistentDomain(forName: name) }
        d.set(true, forKey: "strip.developed.me.2026-10-08")
        d.set(["A"], forKey: "strip.out.me.2026-10-08")
        d.set("black", forKey: "strip.paper.chosen")
        d.set(true, forKey: TipJar.askedKey)
        d.set(4, forKey: TipJar.stripsKey)
        d.set("2026-10-08", forKey: TipJar.inviteDayKey)
        d.set("install", forKey: Analytics.installKey)
        d.set("2026-10-01", forKey: Analytics.firstDayKey)
        d.set(true, forKey: "hasOnboarded")

        let removed = StoreReset.removeKeepsakes(ink: ink, defaults: d)

        #expect(removed == 4)
        #expect(ink.all().map(\.lastPathComponent) == ["kept"])
        for key in ["strip.developed.me.2026-10-08", "strip.out.me.2026-10-08", "strip.paper.chosen",
                    TipJar.askedKey, TipJar.stripsKey, TipJar.inviteDayKey,
                    Analytics.installKey, Analytics.firstDayKey] {
            #expect(d.object(forKey: key) == nil, "\(key) survived the reset")
        }
        #expect(d.bool(forKey: "hasOnboarded"), "a reset is not a fresh onboarding")
    }

    @Test("the tipped count stays: it records a purchase")
    func theTipStays() {
        let keys = StoreReset.keepsakeKeys(in: [TipJar.tipsKey, TipJar.askedKey, "strip.out.crew.x.2026-10-08", "goalDanceDay"])
        #expect(Set(keys) == [TipJar.askedKey, "strip.out.crew.x.2026-10-08"])
    }

    @Test("every sticker goes, file and all, and the picker is empty")
    func stickersGo() throws {
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let names = ["sticker-aaaa0001.png", "sticker-aaaa0002.png"]
        for n in names { try Data([1]).write(to: dir.appendingPathComponent(n)) }
        try JSONEncoder().encode(names).write(to: dir.appendingPathComponent("index.json"))
        let store = StickerStore(directory: dir)
        #expect(store.names == names)
        store.removeAll()
        #expect(store.names.isEmpty)
        for n in names { #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(n).path)) }
        #expect(StickerStore(directory: dir).names.isEmpty, "the index says empty too")
    }
}
