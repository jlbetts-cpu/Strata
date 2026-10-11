import Foundation
import Security

/// **Your crews outlive the app on your phone** (the owner, 2026-10-10:
/// "every time a new build is pushed to TestFlight, all existing crews
/// disappear ... it must persist across builds").
///
/// A crew's posts live in iCloud's public database and stay there. What a
/// phone needs to open them is small: each crew's key, and which person in
/// the crew this account is. Both were kept in the app's own settings, which
/// go when the app is deleted, with one copy in your private iCloud. That
/// copy needs iCloud storage, and an iCloud that is full refuses it: the very
/// thing that moved crews off personal iCloud in the first place. So for
/// anyone with a full iCloud, deleting and reinstalling the app, or setting
/// up a new phone, lost every crew for good, with the crews still sitting on
/// the server unopenable.
///
/// The Keychain is the place for this. It is kept when the app is deleted,
/// it travels to your other devices and to a new phone through iCloud
/// Keychain, end to end encrypted, and it uses none of your iCloud storage.
/// Kept per iCloud account, so signing out and back in brings your crews
/// back, and another account on the same phone sees none of them.
///
/// The keys are held as the same text the iCloud copy holds
/// (`CrewKeyBackup`), so the one set of rules decides what a copy means: a
/// crew you left stays left, and a key another phone of yours took is taken.
nonisolated struct CrewVault: Sendable {
    var read: @Sendable (_ name: String) -> String?
    var write: @Sendable (_ text: String?, _ name: String) -> Void

    func keys(for account: String) -> String? { read("keys-" + account) }
    func setKeys(_ text: String, for account: String) { write(text.isEmpty ? nil : text, "keys-" + account) }

    func identity(for account: String) -> UUID? { read("me-" + account).flatMap(UUID.init(uuidString:)) }
    func setIdentity(_ id: UUID, for account: String) { write(id.uuidString, "me-" + account) }

    /// The phone's own, in the Keychain.
    static let keychain = CrewVault(read: Keychain.read, write: Keychain.write)

    /// One that forgets with the process, for tests.
    static func memory() -> CrewVault {
        let box = Box()
        return CrewVault(read: { box.get($0) }, write: { box.set($0, $1) })
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var held: [String: String] = [:]
        func get(_ name: String) -> String? { lock.withLock { held[name] } }
        func set(_ text: String?, _ name: String) { lock.withLock { held[name] = text } }
    }

    private enum Keychain {
        static let service = "JaydenBetts.Strata.crewVault"

        static func query(_ name: String) -> [String: Any] {
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrService as String: service,
             kSecAttrAccount as String: name,
             kSecAttrSynchronizable as String: kSecAttrSynchronizableAny]
        }

        static func read(_ name: String) -> String? {
            var find = query(name)
            find[kSecReturnData as String] = true
            find[kSecMatchLimit as String] = kSecMatchLimitOne
            var found: CFTypeRef?
            guard SecItemCopyMatching(find as CFDictionary, &found) == errSecSuccess, let data = found as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }

        static func write(_ text: String?, _ name: String) {
            guard let text else {
                SecItemDelete(query(name) as CFDictionary)
                return
            }
            let data = Data(text.utf8)
            let status = SecItemUpdate(query(name) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard status == errSecItemNotFound else { return }
            var add = query(name)
            add[kSecAttrSynchronizable as String] = true
            // Readable once the phone has been unlocked since it started: a
            // push that wakes the app in a pocket still finds its crews.
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}
