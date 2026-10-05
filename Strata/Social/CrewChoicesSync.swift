import Foundation

/// **Blocks and mutes, the same on every phone you own.**
///
/// Block someone on your phone and they are gone from your iPad too; mute a
/// crew on one and it is quiet on both. The choices travel through iCloud's
/// key-value store, which is yours alone, never through a crew's zone, so
/// nobody in a crew can see them, and the person you blocked is still not
/// told.
///
/// Each choice is a small table of entries keyed by who or which crew, each
/// stamped with when it was made. Two phones merge by keeping the newer
/// entry, so an unblock on one phone undoes a block made earlier on the other
/// instead of losing to it.
enum CrewChoicesSync {
    /// The tables. Their names are the keys in iCloud.
    enum Table: String, CaseIterable {
        /// Value 1 blocked, 0 unblocked; "n" keeps the name for the Blocked list.
        case blocked = "crews.sync.blocked"
        /// Value is when the mute ends (seconds since 1970); 0 is unmuted.
        case muted = "crews.sync.muted"
        /// Value 1 when reaction alerts are off for that crew.
        case reactionsOff = "crews.sync.reactionsOff"
        /// Value 1 for a win hidden from you (`SocialStore.hide`).
        case hidden = "crews.sync.hiddenWins"
    }

    typealias Entries = [String: [String: Any]]

    static func entry(_ value: Double, at stamp: Double, name: String? = nil) -> [String: Any] {
        var entry: [String: Any] = ["v": value, "t": stamp]
        if let name { entry["n"] = name }
        return entry
    }

    static func value(_ entry: [String: Any]?) -> Double { (entry?["v"] as? Double) ?? 0 }
    static func stamp(_ entry: [String: Any]?) -> Double { (entry?["t"] as? Double) ?? -1 }
    static func name(_ entry: [String: Any]?) -> String? { entry?["n"] as? String }

    /// Both sides, keeping the newer entry for every key.
    static func merge(_ mine: Entries, _ theirs: Entries) -> Entries {
        var out = mine
        for (key, entry) in theirs where stamp(entry) > stamp(out[key]) {
            out[key] = entry
        }
        return out
    }

    /// Whether `merged` holds anything `remote` does not have yet, so a
    /// phone writes to iCloud only when it knows something new.
    static func isAhead(_ merged: Entries, of remote: Entries) -> Bool {
        merged.contains { key, entry in stamp(entry) > stamp(remote[key]) }
    }
}

/// iCloud's key-value store, or a stand-in for tests.
protocol KeyValueCloud: AnyObject {
    func dictionary(forKey key: String) -> [String: Any]?
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueCloud {}

/// An iCloud for tests: two stores sharing one of these are two phones on
/// one account.
final class MemoryKeyValueCloud: KeyValueCloud {
    private var values: [String: Any] = [:]
    func dictionary(forKey key: String) -> [String: Any]? { values[key] as? [String: Any] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func synchronize() -> Bool { true }
}
