import Observation
import SwiftUI
import UIKit

/// Who the profile belongs to: a name and the colour behind your head, on
/// this phone and nowhere else.
///
/// **No photograph** (the owner, 2026-10-14: "remove the option for a pfp").
/// Your picture is your head (`PersonHead`), so the photo this store used to
/// hold is never read, drawn or sent; the file an older build wrote is
/// removed when a head is made (`removeOldPhoto`) and by Reset All Data.
///
/// A singleton because the picture is drawn in two places at once, the
/// Memories header and Profile itself, and both must change the moment it
/// does. Not SwiftData: this is one person's settings, not a record, and it
/// must survive the store being reset for a test.
@Observable
@MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    private(set) var name: String
    /// The colour behind your head in the profile picture, from the app's own
    /// block palette. Nil is the neutral fill.
    private(set) var background: HabitCategory?

    /// A random id for the person this phone belongs to, made once and never
    /// changed.
    ///
    /// **Nothing uses it yet, on purpose.** Every future system that has to
    /// say "this person" (a shared week, a circle, a server row) keys by this,
    /// and an iCloud user record id or a Sign in with Apple subject gets mapped
    /// TO it rather than becoming it. It has to exist before any of those do,
    /// or the first one to ship becomes the identity by accident.
    ///
    /// In UserDefaults because there is no identity model yet. Not cleared by
    /// `reset()`: Reset All Data empties the record, not who you are.
    ///
    /// The first read creates it, under a lock, so two first readers cannot
    /// each make a different one and the second overwrite the first.
    /// Something that only wants to LOOK (a report, a probe) reads
    /// `storedProfileID`, which never writes.
    nonisolated static var profileID: UUID { profileID(in: .standard) }

    /// The id if one has been made, without making one.
    nonisolated static var storedProfileID: UUID? { storedProfileID(in: .standard) }

    /// `defaults` is a parameter so a test can use its own suite and never
    /// touch the real id in the test host.
    nonisolated static func profileID(in defaults: UserDefaults) -> UUID {
        profileIDLock.lock(); defer { profileIDLock.unlock() }
        if let id = storedProfileID(in: defaults) { return id }
        let id = UUID()
        defaults.set(id.uuidString, forKey: profileIDKey)
        return id
    }

    nonisolated static func storedProfileID(in defaults: UserDefaults) -> UUID? {
        defaults.string(forKey: profileIDKey).flatMap(UUID.init(uuidString:))
    }

    nonisolated static let profileIDKey = "profileID"
    nonisolated private static let profileIDLock = NSLock()

    private static let nameKey = "profileName"
    private static let backgroundKey = "profileBackground"
    /// The largest the picture is drawn is 88pt — 264px at 3x. 600 leaves
    /// room without holding a camera-sized image in memory for a circle.
    private init() {
        name = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        background = UserDefaults.standard.string(forKey: Self.backgroundKey).flatMap(HabitCategory.init(rawValue:))
    }

    /// **Never empty** (the owner, 2026-10-14: "everyone should have a
    /// name"): a name with no words in it is not saved.
    func setName(_ newValue: String) {
        guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        name = newValue
        UserDefaults.standard.set(newValue, forKey: Self.nameKey)
        SocialStore.noteMyselfChanged()
    }

    func setBackground(_ colour: HabitCategory?) {
        background = colour
        UserDefaults.standard.set(colour?.rawValue, forKey: Self.backgroundKey)
    }

    /// The fill behind your head in Profile and the header button.
    ///
    /// **An empty one is the platform's well, a chosen one is ours.**
    ///
    /// The empty case was `.quaternary`, then `quietFill`, and it goes back:
    /// Profile is a screen the owner asked to be Apple-native (2026-09-30), and
    /// on a clean white page `.quaternary` is a quiet disc rather than the heavy
    /// grey it was on the lower, warmer ground that argument was made against.
    ///
    /// A CHOSEN colour stays lit from inside, because that is content rather
    /// than chrome — it is the same colour, lit the same way, as the block it
    /// will put on the tower and the swatch it was picked with.
    var backgroundStyle: AnyShapeStyle {
        // **`quietFill`, and it was `.quaternary`.** Measured on the built
        // Profile at (203, 203, 202) on a 247 page, which is 1.51:1 and is a
        // system hierarchical grey rather than one of this app's. The design
        // doc refuses those by name and `ProfileView`'s own colour swatch ten
        // points below this one already refused it in a comment; the default
        // underneath them both did not. It is the avatar's ground, so it is
        // what the drawing in `docs/illustrations.md` will land on.
        background.map { AnyShapeStyle(EtherealFill.fill($0.style.baseColor)) }
            ?? AnyShapeStyle(AppColors.quietFill)
    }

    /// **The profile photograph an older build saved, deleted** (the owner's
    /// call, 2026-10-14: when a head is made). Nothing reads it since the
    /// head became the picture. Removing a file that is not there does
    /// nothing, so a second call is free.
    func removeOldPhoto() {
        guard let url = Self.photoURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Everything, for Reset All Data, which the privacy policy says removes
    /// every photo; an old profile photo left on the phone is one.
    func reset() {
        removeOldPhoto()
        // The one way a name goes: everything is reset, and onboarding asks
        // for one again before anyone sees it.
        name = ""
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        SocialStore.noteMyselfChanged()
        setBackground(nil)
    }

    private static var photoURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "Profile", directoryHint: .isDirectory)
            .appending(path: "photo.jpg")
    }
}
