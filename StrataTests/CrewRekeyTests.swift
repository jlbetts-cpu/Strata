import CryptoKit
import Foundation
import Testing
@testable import Strata

/// **A crew gets a new key when someone is removed** (`CrewRekey`,
/// 2026-10-10). The removed person holds the old key and must not get the
/// new one; everyone else must; nobody but the starter may hand one out.
@Suite("Crew re-key")
struct CrewRekeyTests {
    let crew = "crew-3F2504E0"
    let k0 = CrewKey.new(), k1 = CrewKey.new(), k2 = CrewKey.new()
    let ana = Curve25519.KeyAgreement.PrivateKey()
    let leo = Curve25519.KeyAgreement.PrivateKey()
    let removed = Curve25519.KeyAgreement.PrivateKey()

    func text(_ key: Curve25519.KeyAgreement.PrivateKey) -> String { key.publicKey.rawRepresentation.base64EncodedString() }

    func seen(new: CrewKey, old: CrewKey, to people: [Curve25519.KeyAgreement.PrivateKey], starter: Bool = true,
              at: Double) throws -> CrewRekey.Seen {
        let data = try CrewRekey.make(new: new, old: old, recipients: people.map(text), crew: crew)
        return CrewRekey.Seen(box: try #require(CrewRekey.read(data)), fromStarter: starter, at: Date(timeIntervalSince1970: at))
    }

    @Test("a remaining member gets the new key, and keeps the old one for reading")
    func memberLearns() throws {
        let record = try seen(new: k1, old: k0, to: [ana, leo], at: 100)
        let learned = CrewRekey.learn([record], crew: crew, current: k0, older: [], mine: ana)
        #expect(learned.current == k1)
        #expect(learned.older == [k0])
    }

    @Test("the removed person, holding the old key and the whole record, gets nothing")
    func removedLearnsNothing() throws {
        let record = try seen(new: k1, old: k0, to: [ana, leo], at: 100)
        let learned = CrewRekey.learn([record], crew: crew, current: k0, older: [], mine: removed)
        #expect(!learned.changed)
        // Nor does the record give the new key away in the clear.
        let data = try CrewRekey.make(new: k1, old: k0, recipients: [text(ana)], crew: crew)
        #expect(data.range(of: k1.bytes) == nil)
        #expect(!String(decoding: data, as: UTF8.self).contains(k1.bytes.base64EncodedString()))
    }

    @Test("a key offered by anyone but the starter is not taken")
    func onlyTheStarter() throws {
        // The removed person writes their own "rekey", to a key they chose.
        let forged = try seen(new: k2, old: k0, to: [ana, leo], starter: false, at: 200)
        let learned = CrewRekey.learn([forged], crew: crew, current: k0, older: [], mine: ana)
        #expect(learned.current == nil)
    }

    @Test("someone invited after the change, holding only the new key, can read what came before")
    func joinerReadsBack() throws {
        let first = try seen(new: k1, old: k0, to: [ana], at: 100)
        let second = try seen(new: k2, old: k1, to: [ana], at: 200)
        // Even before they know who the starter is.
        let learned = CrewRekey.learn([second, first].map { var s = $0; s.fromStarter = false; return s },
                                      crew: crew, current: k2, older: [], mine: leo)
        #expect(learned.current == nil)
        #expect(Set(learned.older.map(\.mark)) == [k0.mark, k1.mark])
    }

    @Test("two re-keys read in any order end on the newest")
    func order() throws {
        let first = try seen(new: k1, old: k0, to: [ana], at: 100)
        let second = try seen(new: k2, old: k1, to: [ana], at: 200)
        for records in [[first, second], [second, first]] {
            let learned = CrewRekey.learn(records, crew: crew, current: k0, older: [], mine: ana)
            #expect(learned.current == k2)
            #expect(Set(learned.older.map(\.mark)) == [k0.mark, k1.mark])
        }
        // And reading them again changes nothing.
        #expect(!CrewRekey.learn([first, second], crew: crew, current: k2, older: [k1, k0], mine: ana).changed)
    }

    /// The re-key review's cases (2026-10-10).
    @Test("made-up earlier keys from someone holding an old key are not followed, once the starter is known")
    func forgedChain() throws {
        let real = try seen(new: k1, old: k0, to: [ana], at: 100)
        // The removed person, who holds K0: "the key before K0 was this".
        var junk: [CrewRekey.Seen] = []
        for i in 0..<20 {
            let data = try JSONEncoder().encode(CrewRekey.Box(
                mark: k0.mark, wraps: [:],
                prev: try k0.seal(CrewKey.new().bytes, context: "\(crew)|rekey-prev").base64EncodedString()))
            junk.append(.init(box: try #require(CrewRekey.read(data)), fromStarter: false, at: Date(timeIntervalSince1970: 200 + Double(i))))
        }
        let learned = CrewRekey.learn(junk + [real], crew: crew, current: k1, older: [k0], mine: ana, starterKnown: true)
        #expect(!learned.changed, "nothing to learn, so nothing to read again")
    }

    @Test("a phone pushed back to an old key returns to the crew's key")
    func returnsToTheRightKey() throws {
        let record = try seen(new: k1, old: k0, to: [ana], at: 100)
        // It knows K1 already, and something put K0 back as its key.
        let learned = CrewRekey.learn([record], crew: crew, current: k0, older: [k1], mine: ana, starterKnown: true)
        #expect(learned.current == k1)
    }

    @Test("a public key that is not one gets no copy, and is known not to be one")
    func notAKey() throws {
        #expect(CrewRekey.isKey(text(ana)))
        #expect(!CrewRekey.isKey("not base64 at all"))
        #expect(!CrewRekey.isKey(Data(repeating: 1, count: 12).base64EncodedString()))
        let data = try CrewRekey.make(new: k1, old: k0, recipients: ["junk", text(ana)], crew: crew)
        #expect(try #require(CrewRekey.read(data)).wraps.keys.sorted() == [text(ana)])
    }

    @Test("a rekey record larger than one could be is not read")
    func oversize() throws {
        let fat = try JSONEncoder().encode(CrewRekey.Box(mark: k1.mark, wraps: ["x": String(repeating: "A", count: 20_000)], prev: ""))
        #expect(CrewRekey.read(fat) == nil)
    }

    @Test("a record for another crew opens nothing here")
    func boundToItsCrew() throws {
        let data = try CrewRekey.make(new: k1, old: k0, recipients: [text(ana)], crew: "crew-OTHER")
        let record = CrewRekey.Seen(box: try #require(CrewRekey.read(data)), fromStarter: true, at: .now)
        #expect(!CrewRekey.learn([record], crew: crew, current: k0, older: [], mine: ana).changed)
    }

    @Test("a phone can tell its key is no longer the crew's")
    func stale() throws {
        let record = try seen(new: k1, old: k0, to: [ana], at: 100)
        #expect(!CrewRekey.isCurrent(k0, seen: [record]))
        #expect(CrewRekey.isCurrent(k1, seen: [record]))
        #expect(CrewRekey.isCurrent(k0, seen: []))
    }

    @Test("the key ring keeps the keys before, current first, and forgets them with the crew")
    func ring() {
        let ring = CrewKeyRing(suite: "rekey-tests-\(UUID().uuidString)")
        ring.set(k0, for: crew)
        ring.advance(to: k1, for: crew)
        #expect(ring.all[crew] == k1)
        #expect(ring.candidates(for: crew) == [k1, k0])
        ring.advance(to: k1, for: crew)
        ring.remember(k0, for: crew)
        #expect(ring.candidates(for: crew) == [k1, k0], "nothing twice")
        ring.advance(to: k2, for: crew)
        #expect(ring.candidates(for: crew) == [k2, k1, k0])
        ring.set(nil, for: crew)
        #expect(ring.candidates(for: crew).isEmpty)
    }

    @Test("a post sealed before the re-key is still read after it, by the extension too")
    func oldPostsStillOpen() throws {
        let name = CrewItemRecord.name(crew: crew, kind: "SharedWin", name: "w1")
        let folder = FileManager.default.temporaryDirectory.appending(path: "rk-\(UUID().uuidString)")
        let sealed = try CrewItemBox.seal(["title": .string("Gym")], key: k0, recordName: name, folder: folder)
        #expect(CrewItemRecord.strings(in: sealed.box, keys: [k1, k0], recordName: name)["title"] == "Gym")
        #expect(CrewItemRecord.strings(in: sealed.box, keys: [k1], recordName: name).isEmpty)
    }

    @Test("your other phone takes the crew's new key from the key backup")
    func backupCarriesTheNewKey() {
        let local = CrewKeyBackup.Local(keys: [crew: k0.linkText], keyedAt: [crew: 100])
        let remote = CrewKeyBackup.Remote(keys: [crew: k1.linkText], keyedAt: [crew: 500])
        let merged = CrewKeyBackup.merge(local: local, remote: remote, now: 600)
        #expect(merged.take == [crew: k1.linkText])
        #expect(merged.out.keys == [crew: k1.linkText] && merged.out.keyedAt[crew] == 500)
        // And the phone that re-keyed is not pulled back to the old one.
        let ahead = CrewKeyBackup.Local(keys: [crew: k1.linkText], keyedAt: [crew: 500])
        let behind = CrewKeyBackup.Remote(keys: [crew: k0.linkText], keyedAt: [crew: 100])
        let kept = CrewKeyBackup.merge(local: ahead, remote: behind, now: 600)
        #expect(kept.take.isEmpty && kept.out.keys == [crew: k1.linkText])
    }
}
