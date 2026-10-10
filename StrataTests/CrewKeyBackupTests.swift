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

    @Test("text round trips keys, when they were joined, and left crews; junk is ignored")
    func roundTrip() {
        let remote = CrewKeyBackup.Remote(keys: [x: key1], keyedAt: [x: 1_700_000_000], left: [y: 1_800_000_000])
        #expect(CrewKeyBackup.parse(CrewKeyBackup.text(remote)) == remote)
        #expect(CrewKeyBackup.parse("nonsense,crew-1.short,\(x).\(key1)").keys == [x: key1])
    }

    /// The second review's case: A leaves at t1 and B learns of it; A joins
    /// again by a fresh link at t2. B must take the key back, and must not
    /// write the old note over it.
    @Test("a rejoin on one phone reaches the other, and neither undoes it")
    func rejoinReachesTheOtherPhone() {
        // B: holds only the note that the crew was left at 2,000.
        let b = CrewKeyBackup.Local(leftAt: [x: 2_000])
        let fromA = CrewKeyBackup.Remote(keys: [x: key2], keyedAt: [x: 5_000])
        let merged = CrewKeyBackup.merge(local: b, remote: fromA, now: 6_000)
        #expect(merged.take == [x: key2])
        #expect(merged.out.keys == [x: key2] && merged.out.keyedAt[x] == 5_000)
        #expect(merged.out.left.isEmpty, "the old note goes; it is not written back over the key")
        // And what B wrote is stable when A reads it back.
        let a = CrewKeyBackup.Local(keys: [x: key2], keyedAt: [x: 5_000])
        let again = CrewKeyBackup.merge(local: a, remote: merged.out, now: 7_000)
        #expect(again.forget.isEmpty && again.out == merged.out)
    }

    @Test("a key joined before the crew was left is not taken back")
    func staleKeyStaysOut() {
        let b = CrewKeyBackup.Local(leftAt: [x: 2_000])
        let merged = CrewKeyBackup.merge(local: b, remote: .init(keys: [x: key1], keyedAt: [x: 1_000]), now: 3_000)
        #expect(merged.take.isEmpty && merged.out.keys.isEmpty && merged.out.left[x] == 2_000)
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
        #expect(CrewKeyWrap.open(stored, with: nil) == nil, "sealed by another phone, no key here: unread, not empty")
    }

    // MARK: - Whether you have left (`CrewLeaving`)

    private func at(_ t: Double) -> Date { Date(timeIntervalSince1970: t) }

    @Test("a note with no member record of yours means you left")
    func leftNoMember() {
        #expect(CrewLeaving.isLeft(notes: [.init(name: "Left/a", written: at(200))], answered: [], member: .none))
    }

    @Test("your other phone still shows the old member record: the newer note wins")
    func leftOlderMember() {
        #expect(CrewLeaving.isLeft(notes: [.init(name: "Left/a", written: at(200))], answered: [], member: .at(at(100))))
    }

    @Test("joined again since: an old note left lying about means nothing, on any phone")
    func rejoinedSince() {
        #expect(!CrewLeaving.isLeft(notes: [.init(name: "Left/a", written: at(200))], answered: [], member: .at(at(300))))
        #expect(!CrewLeaving.isLeft(notes: [.init(name: "Left/a", written: at(200))], answered: [], member: .justWritten))
    }

    @Test("a join answers the notes it found, even before the member record is written")
    func answered() {
        let note = CrewLeaving.Note(name: "Left/a", written: at(200))
        #expect(!CrewLeaving.isLeft(notes: [note], answered: ["Left/a"], member: .none))
        // A later leaving is a new note, and counts.
        #expect(CrewLeaving.isLeft(notes: [note, .init(name: "Left/b", written: at(400))], answered: ["Left/a"], member: .at(at(300))))
    }

    @Test("the note this phone is writing right now decides nothing")
    func midLeave() {
        #expect(!CrewLeaving.isLeft(notes: [.init(name: "Left/a", written: nil)], answered: [], member: .none))
    }
}
