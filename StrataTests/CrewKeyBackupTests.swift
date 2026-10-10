import Foundation
import Testing
@testable import Strata

/// Your crew keys across your own phones (`CrewKeyBackup`, the 2026-10-10
/// review): leaving sticks, one phone never erases another's keys, and the
/// backup is sealed.
@Suite("Crew key backup")
struct CrewKeyBackupTests {
    let x = "crew-AAAA", y = "crew-BBBB"
    let key1 = CrewKey.new().linkText, key2 = CrewKey.new().linkText

    @Test("text round trips keys and left crews, and junk is ignored")
    func roundTrip() {
        let remote = CrewKeyBackup.Remote(keys: [x: key1], left: [y: 1_800_000_000])
        #expect(CrewKeyBackup.parse(CrewKeyBackup.text(remote)) == remote)
        #expect(CrewKeyBackup.parse("nonsense,crew-1.short,\(x).\(key1)").keys == [x: key1])
    }

    @Test("a crew left on another phone is dropped here, not re-joined")
    func leavingSticks() {
        // Phone B still holds the key from last week; phone A left yesterday.
        let local = CrewKeyBackup.Local(keys: [x: key1], keyedAt: [x: 1_000])
        let merged = CrewKeyBackup.merge(local: local, remote: .init(left: [x: 2_000]), now: 3_000)
        #expect(merged.forget == [x])
        #expect(merged.out.keys.isEmpty)
        #expect(merged.out.left[x] == 2_000)
    }

    @Test("a key the backup still holds does not bring back a crew this phone left")
    func failedBackup() {
        // Left here; the backup after it failed, so the record still has the key.
        let local = CrewKeyBackup.Local(leftAt: [x: 2_000])
        let merged = CrewKeyBackup.merge(local: local, remote: .init(keys: [x: key1]), now: 3_000)
        #expect(merged.take.isEmpty)
        #expect(merged.out.keys.isEmpty && merged.out.left[x] == 2_000)
    }

    @Test("joining again by a fresh link beats an older leaving")
    func rejoin() {
        let local = CrewKeyBackup.Local(keys: [x: key2], keyedAt: [x: 5_000])
        let merged = CrewKeyBackup.merge(local: local, remote: .init(left: [x: 2_000]), now: 6_000)
        #expect(merged.forget.isEmpty)
        #expect(merged.out.keys == [x: key2])
        #expect(merged.out.left.isEmpty)
    }

    @Test("another phone's newer key is taken and kept in the backup")
    func mergesKeys() {
        let local = CrewKeyBackup.Local(keys: [x: key1], keyedAt: [x: 1_000])
        let merged = CrewKeyBackup.merge(local: local, remote: .init(keys: [y: key2]), now: 2_000)
        #expect(merged.take == [y: key2])
        #expect(merged.out.keys == [x: key1, y: key2])
    }

    @Test("a leaving is forgotten after half a year")
    func pruned() {
        let merged = CrewKeyBackup.merge(local: .init(), remote: .init(left: [x: 0]), now: CrewKeyBackup.leftFor + 1)
        #expect(merged.out.left.isEmpty)
    }

    @Test("the backup is sealed, opens with its key and with nothing else")
    func sealed() throws {
        let wrap = CrewKey.new()
        let text = "\(x).\(key1)"
        let stored = try #require(CrewKeyWrap.seal(text, with: wrap))
        #expect(stored.hasPrefix(CrewKeyWrap.prefix))
        #expect(!stored.contains(key1), "the key is not in the stored text")
        #expect(CrewKeyWrap.open(stored, with: wrap) == text)
        #expect(CrewKeyWrap.open(stored, with: CrewKey.new()) == nil)
        // One written before sealing is still read, once.
        #expect(CrewKeyWrap.open(text, with: wrap) == text)
        #expect(CrewKeyWrap.seal(text, with: nil) == nil, "no key, nothing written in the clear")
    }
}
