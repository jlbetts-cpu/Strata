import CryptoKit
import Foundation
import Security

/// **Your crew keys across your own phones** (the 2026-10-10 review of the
/// public-database move).
///
/// One small record in your private iCloud carries every crew key this
/// account holds, so a second phone of yours is in the same crews. Three
/// things the first version got wrong, all found by reading:
///
/// - **Leaving did not stick.** The backup was only ever keys, so a second
///   phone (or this one, after a backup that failed) put the key back and
///   the app re-joined the crew for you. A crew you leave is now written
///   down as left, with when, and that beats any older key anywhere.
/// - **One phone could erase another's keys.** Each backup wrote only what
///   that phone held. It is merged now.
/// - **The keys were readable by the server.** A crew is sealed end to end,
///   and its key sat beside it in plain text in the same iCloud container.
///   The backup is sealed with a key that lives only in your iCloud Keychain
///   (`CrewKeyWrap`), which Apple cannot read.
///
/// Pure: text in, decisions out. `PublicCrewCloud` does the CloudKit.
nonisolated enum CrewKeyBackup {
    /// What the record holds: keys by crew with when each was joined, and
    /// crews left with when.
    struct Remote: Equatable {
        var keys: [String: String] = [:]
        /// When each key was joined, on whichever phone joined it. **In the
        /// backup, not only on the phone** (found 2026-10-10 by the second
        /// review): without it a phone holding an old "left" note could not
        /// tell a stale key from a fresh rejoin on your other phone, refused
        /// the key, and wrote the note back over it, each phone undoing the
        /// other for ever.
        var keyedAt: [String: Double] = [:]
        var left: [String: Double] = [:]
    }

    /// What this phone holds.
    struct Local: Equatable {
        var keys: [String: String] = [:]
        /// When each key arrived here. A key with no time is older than
        /// anything.
        var keyedAt: [String: Double] = [:]
        var leftAt: [String: Double] = [:]
    }

    struct Merged: Equatable {
        /// Crews whose key this phone should drop: left since it was kept.
        var forget: [String] = []
        /// Keys another phone of yours has that this one should take.
        var take: [String: String] = [:]
        /// What to write back, and what this phone's own times become.
        var out = Remote()
    }

    /// A left crew is remembered this long, then the note goes.
    static let leftFor: Double = 180 * 86_400
    /// A left crew's entry: the crew, a dot, `!`, and when. `!` is not a
    /// character a key can hold, so no build reads one as a key.
    private static let leftMark: Character = "!"
    /// Between a key and when it was joined: `crew.key@time`.
    private static let timeMark: Character = "@"

    static func parse(_ text: String) -> Remote {
        var remote = Remote()
        for item in text.split(separator: ",") {
            guard let dot = item.lastIndex(of: ".") else { continue }
            let crew = String(item[..<dot])
            let value = item[item.index(after: dot)...]
            if value.first == leftMark {
                if let when = Double(value.dropFirst()) { remote.left[crew] = when }
                continue
            }
            let parts = value.split(separator: timeMark, maxSplits: 1)
            guard let key = parts.first.map(String.init), CrewKey(linkText: key) != nil else { continue }
            remote.keys[crew] = key
            if parts.count == 2, let when = Double(parts[1]) { remote.keyedAt[crew] = when }
        }
        return remote
    }

    static func text(_ remote: Remote) -> String {
        (remote.keys.map { "\($0.key).\($0.value)\(timeMark)\(Int(remote.keyedAt[$0.key] ?? 0))" }
            + remote.left.map { "\($0.key).\(leftMark)\(Int($0.value))" })
            .sorted().joined(separator: ",")
    }

    static func merge(local: Local, remote: Remote, now: Double) -> Merged {
        var merged = Merged()
        func leftAt(_ crew: String) -> Double { max(local.leftAt[crew] ?? 0, remote.left[crew] ?? 0) }
        for (crew, key) in local.keys {
            // The same key joined later on another phone counts as joined then.
            let joined = max(local.keyedAt[crew] ?? 0, remote.keys[crew] == key ? (remote.keyedAt[crew] ?? 0) : 0)
            // Left after this key arrived: the leaving wins. Joined again
            // since (a fresh link): the key wins and the note is dropped.
            if leftAt(crew) > joined {
                merged.forget.append(crew)
            } else {
                merged.out.keys[crew] = key
                merged.out.keyedAt[crew] = joined
            }
        }
        for (crew, key) in remote.keys where local.keys[crew] == nil {
            // Another phone's key: taken unless the crew was left since it
            // was joined there.
            let joined = remote.keyedAt[crew] ?? 0
            guard leftAt(crew) == 0 || joined > leftAt(crew) else { continue }
            merged.take[crew] = key
            merged.out.keys[crew] = key
            merged.out.keyedAt[crew] = joined
        }
        for crew in Set(local.leftAt.keys).union(remote.left.keys) where merged.out.keys[crew] == nil {
            let when = leftAt(crew)
            if now - when < leftFor { merged.out.left[crew] = when }
        }
        merged.forget.sort()
        return merged
    }
}

/// **Whether this account has left a crew**, decided from the crew's own
/// records and the server's own times (the third read, 2026-10-10).
///
/// Leaving writes a small sealed note into the crew (`PublicCrewCloud
/// .leftKind`). The first version compared the note's time with a time kept
/// on each phone, and every gap between the two (a join still in flight, a
/// note that could not be removed, a phone that had not looked yet) let one
/// phone undo what another had just done. This rule needs neither clock nor
/// phone to agree:
///
/// - a note this phone has already **answered** (it joined by a link with
///   the note in view) never counts again;
/// - any other note counts when there is **no member record of yours**, or
///   when the note is **newer than your member record**, both as the server
///   stamped them. Joining again writes a new member record, so an old note
///   left lying around by a failed clean-up means nothing, on any phone.
nonisolated enum CrewLeaving {
    struct Note: Equatable {
        var name: String
        /// When the server took it. Nil for one this phone wrote a moment
        /// ago: it is in the middle of leaving and decides nothing here.
        var written: Date?
    }

    enum Member: Equatable {
        case none
        /// Written by this phone and not yet read back: newer than any note.
        case justWritten
        case at(Date)
    }

    static func isLeft(notes: [Note], answered: Set<String>, member: Member) -> Bool {
        notes.contains { note in
            guard !answered.contains(note.name), let written = note.written else { return false }
            switch member {
            case .none: return true
            case .justWritten: return false
            case .at(let joined): return written > joined
            }
        }
    }
}

/// **The key the backup is sealed with**, kept in the iCloud Keychain so it
/// reaches your other phones end to end and never sits in CloudKit. Without
/// iCloud Keychain it stays on this phone, and a second phone joins by the
/// invite link instead, as it does when iCloud is full.
nonisolated enum CrewKeyWrap {
    private static let service = "JaydenBetts.Strata.crewKeyBackup"
    private static let account = "wrap-v1"
    static let prefix = "v2:"
    private static let context = "crew-key-backup"

    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// The wrapping key this phone has, or nil. **Looking never makes one**
    /// (found 2026-10-10 by the second review): opening a backup another
    /// phone sealed used to mint a key on a miss, and a key minted before
    /// the real one arrived could win in the iCloud Keychain and leave the
    /// backup unopenable by every phone.
    static func existing() -> CrewKey? {
        var find = query()
        find[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        find[kSecReturnData as String] = true
        find[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: CFTypeRef?
        guard SecItemCopyMatching(find as CFDictionary, &found) == errSecSuccess,
              let data = found as? Data, data.count == 32 else { return nil }
        return CrewKey(bytes: data)
    }

    /// The wrapping key, made if there is none: only for writing a backup
    /// where none sealed by another phone stands.
    static func key() -> CrewKey? {
        if let existing = existing() { return existing }
        let fresh = CrewKey.new()
        var add = query()
        add[kSecAttrSynchronizable as String] = true
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecValueData as String] = fresh.bytes
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess ? fresh : existing()
    }

    /// The backup's text, sealed. Nil when there is no key to seal it with:
    /// then nothing is written, rather than the keys in the clear.
    static func seal(_ text: String, with key: CrewKey? = CrewKeyWrap.key()) -> String? {
        guard let key, let sealed = try? key.seal(Data(text.utf8), context: context) else { return nil }
        return prefix + sealed.base64EncodedString()
    }

    /// What a stored backup says: a sealed one opened, one from before
    /// sealing read as it is, and one sealed with a key this phone does not
    /// have as nothing.
    static func open(_ stored: String, with key: CrewKey? = CrewKeyWrap.existing()) -> String? {
        guard stored.hasPrefix(prefix) else { return stored }
        guard let key, let sealed = Data(base64Encoded: String(stored.dropFirst(prefix.count))),
              let plain = try? key.open(sealed, context: context) else { return nil }
        return String(data: plain, encoding: .utf8)
    }
}
