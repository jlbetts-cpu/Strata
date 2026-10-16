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
    private static let bannerKey = "profileBannerByMonth"
    private static let bannerLayoutKey = "profileBannerLayoutByMonth"
    private static let usesPhotoKey = "profileUsesPhoto"

    /// **A photograph instead of a head, when you would rather** (the owner,
    /// 2026-10-16: "there should be a way to add a pfp instead of a head if
    /// the user wants to"). Kept on this phone; sent to your crews by the
    /// photo rule and the photo check, as a win's photograph is.
    var usesPhoto: Bool { UserDefaults.standard.bool(forKey: Self.usesPhotoKey) && photoImage != nil }

    @ObservationIgnored private var photoCache: UIImage?
    @ObservationIgnored private var photoCacheRead = false

    /// Yours, read once.
    var photoImage: UIImage? {
        _ = bannerChanged
        if !photoCacheRead {
            photoCacheRead = true
            photoCache = Self.photoURL.flatMap { try? Data(contentsOf: $0) }.flatMap(UIImage.init(data:))
        }
        return photoCache
    }

    /// The photograph as it is sent: the file's own bytes.
    var photoData: Data? { usesPhoto ? Self.photoURL.flatMap { try? Data(contentsOf: $0) } : nil }

    /// Takes a photograph as your picture, square and small enough to send.
    func usePhoto(_ jpeg: Data) {
        guard let url = Self.photoURL, let square = Self.square(jpeg) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? square.write(to: url, options: .atomic)
        photoCacheRead = false
        UserDefaults.standard.set(true, forKey: Self.usesPhotoKey)
        bannerChanged += 1
        SocialStore.noteMyselfChanged()
    }

    /// Back to your head: the photograph goes.
    func useHead() {
        UserDefaults.standard.set(false, forKey: Self.usesPhotoKey)
        removeOldPhoto()
        photoCacheRead = false
        bannerChanged += 1
        SocialStore.noteMyselfChanged()
    }

    /// The middle square, 600 pixels across.
    private static func square(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2, width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let out = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 600), format: format).image { _ in
            image.draw(in: CGRect(x: -crop.minX * 600 / side, y: -crop.minY * 600 / side,
                                  width: image.size.width * 600 / side, height: image.size.height * 600 / side))
        }
        return out.jpegData(compressionQuality: 0.85)
    }
    private static let handleKey = "profileHandle"
    private static let handleSetKey = "profileHandleSetAt"

    /// **Your username** (`Handle`), once you have claimed one, and when.
    var handle: String? { UserDefaults.standard.string(forKey: Self.handleKey) }
    var handleSetAt: Date? { UserDefaults.standard.object(forKey: Self.handleSetKey) as? Date }

    /// Gone from this phone (another iCloud account signed in).
    func forgetHandle() {
        UserDefaults.standard.removeObject(forKey: Self.handleKey)
        UserDefaults.standard.removeObject(forKey: Self.handleSetKey)
        bannerChanged += 1
    }

    /// Kept once the public database has given it to you (`SocialStore.setHandle`).
    func keepHandle(_ handle: String, at date: Date = Date()) {
        UserDefaults.standard.set(handle, forKey: Self.handleKey)
        UserDefaults.standard.set(date, forKey: Self.handleSetKey)
        bannerChanged += 1
    }
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

    /// **The banner's photographs, as you chose them, a month at a time**
    /// (2026-10-16; the owner: "the banner can be edited but has to use
    /// images from that month"). Keyed by "yyyy-MM"; a month with none is
    /// automatic, its latest photographed wins. Kept on this phone only.
    func bannerFiles(for month: String) -> [String] {
        (UserDefaults.standard.dictionary(forKey: Self.bannerKey) as? [String: [String]])?[month] ?? []
    }

    /// Which arrangement a month's banner takes (`ProfileBanner.layouts`).
    func bannerLayout(for month: String) -> Int {
        let index = (UserDefaults.standard.dictionary(forKey: Self.bannerLayoutKey) as? [String: Int])?[month] ?? 0
        return min(max(index, 0), ProfileBanner.layouts.count - 1)
    }

    func setBannerLayout(_ index: Int, for month: String) {
        var all = (UserDefaults.standard.dictionary(forKey: Self.bannerLayoutKey) as? [String: Int]) ?? [:]
        all[month] = index == 0 ? nil : index
        UserDefaults.standard.set(all, forKey: Self.bannerLayoutKey)
        bannerChanged += 1
    }

    func setBanner(_ files: [String], for month: String) {
        var all = (UserDefaults.standard.dictionary(forKey: Self.bannerKey) as? [String: [String]]) ?? [:]
        all[month] = files.isEmpty ? nil : Array(files.prefix(ProfileBanner.most))
        UserDefaults.standard.set(all, forKey: Self.bannerKey)
        bannerChanged += 1
    }

    /// Bumped on a change, so a view reading `bannerFiles` redraws.
    private(set) var bannerChanged = 0

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
        //
        // **Always the grey now** (the owner, 2026-10-16: "remove the option to
        // change the color of the circle background, it should just stay the
        // default grey, looks better"). A colour chosen before stays stored
        // and is never drawn.
        AnyShapeStyle(AppColors.quietFill)
    }

    /// **The profile photograph an older build saved, deleted** (the owner's
    /// call, 2026-10-14: when a head is made). Nothing reads it since the
    /// head became the picture. Removing a file that is not there does
    /// nothing, so a second call is free.
    func removeOldPhoto() {
        // Not the photograph you chose to be seen by (`usesPhoto`).
        guard !usesPhoto else { return }
        guard let url = Self.photoURL, FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Everything, for Reset All Data, which the privacy policy says removes
    /// every photo; an old profile photo left on the phone is one.
    func reset() {
        UserDefaults.standard.set(false, forKey: Self.usesPhotoKey)
        removeOldPhoto()
        photoCacheRead = false
        // The one way a name goes: everything is reset, and onboarding asks
        // for one again before anyone sees it.
        name = ""
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        SocialStore.noteMyselfChanged()
        setBackground(nil)
        UserDefaults.standard.removeObject(forKey: Self.bannerKey)
        UserDefaults.standard.removeObject(forKey: Self.bannerLayoutKey)
        UserDefaults.standard.removeObject(forKey: Self.handleKey)
        UserDefaults.standard.removeObject(forKey: Self.handleSetKey)
        bannerChanged += 1
    }

    private static var photoURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "Profile", directoryHint: .isDirectory)
            .appending(path: "photo.jpg")
    }
}
