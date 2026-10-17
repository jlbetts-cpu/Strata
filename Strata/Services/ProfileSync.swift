import Foundation
import SwiftData

/// **Your profile, the same on every phone you own** (the owner, 2026-10-16,
/// on two of his: "the profile isn't synced to other devices, not only was
/// the banner different but some of the key moments weren't there").
///
/// Your name, your featured wins and their words, and each month's banner
/// and its arrangement travel through iCloud's key-value store, which is
/// yours alone, as blocks and mutes do (`CrewChoicesSync`). Each is an entry
/// stamped with when it was set, and two phones keep the newer one, so a
/// change on either wins over an older one on the other.
///
/// **Wins by their id, never their file.** This phone keeps a choice by the
/// photograph's file name; a file name means nothing on another phone until
/// that win has arrived there, and changes when a photo is replaced. So what
/// travels is each win's id (`HabitLog.id`, which syncs), turned back into
/// this phone's file when it lands. A win that has not arrived yet is
/// skipped for now and found on a later pull, and a partial choice is never
/// written back over the whole one.
@MainActor
final class ProfileSync {
    static let shared = ProfileSync(cloud: NSUbiquitousKeyValueStore.default, defaults: .standard)

    static let cloudKey = "profile.sync"
    private static let stampsKey = "profile.sync.stamps"

    let cloud: KeyValueCloud
    let defaults: UserDefaults
    /// This phone's file for a win, and the win a file belongs to. Set from
    /// the app's store at launch; nil resolves nothing (tests set their own).
    var fileForWin: (UUID) -> String? = { _ in nil }
    var winForFile: (String) -> UUID? = { _ in nil }
    /// The store applied to; the profile itself unless a test says otherwise.
    var profile: () -> ProfileStore = { ProfileStore.shared }
    private var applying = false

    init(cloud: KeyValueCloud, defaults: UserDefaults) {
        self.cloud = cloud
        self.defaults = defaults
    }

    /// The app's own wins, for turning ids and files into each other.
    func useStore(_ container: ModelContainer) {
        let context = ModelContext(container)
        fileForWin = { id in
            var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.id == id })
            d.fetchLimit = 1
            return (try? context.fetch(d))?.first?.imageFileName
        }
        winForFile = { file in
            var d = FetchDescriptor<HabitLog>(predicate: #Predicate { $0.imageFileName == file })
            d.fetchLimit = 1
            return (try? context.fetch(d))?.first?.id
        }
    }

    // MARK: Keys

    enum Field {
        case name, featured, featuredPrompts
        case banner(String), bannerLayout(String)

        var key: String {
            switch self {
            case .name: "name"
            case .featured: "featured"
            case .featuredPrompts: "featuredPrompts"
            case .banner(let month): "banner.\(month)"
            case .bannerLayout(let month): "bannerLayout.\(month)"
            }
        }

        init?(key: String) {
            switch key {
            case "name": self = .name
            case "featured": self = .featured
            case "featuredPrompts": self = .featuredPrompts
            default:
                if key.hasPrefix("banner."), let month = Self.month(key.dropFirst(7)) { self = .banner(month) }
                else if key.hasPrefix("bannerLayout."), let month = Self.month(key.dropFirst(13)) { self = .bannerLayout(month) }
                else { return nil }
            }
        }

        /// "yyyy-MM" and nothing else, so a key from iCloud is never a path.
        private static func month(_ s: Substring) -> String? {
            let parts = s.split(separator: "-")
            guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
                  parts.allSatisfy({ $0.allSatisfy(\.isNumber) }) else { return nil }
            return String(s)
        }
    }

    // MARK: Local changes

    /// A change made on this phone: stamped now and sent.
    func changed(_ field: Field) {
        guard !applying else { return }
        var stamps = localStamps
        stamps[field.key] = Date().timeIntervalSince1970
        defaults.set(stamps, forKey: Self.stampsKey)
        push()
    }

    private var localStamps: [String: Double] {
        defaults.dictionary(forKey: Self.stampsKey) as? [String: Double] ?? [:]
    }

    /// What this phone holds for a field, as it travels.
    private func localValue(_ field: Field) -> Any? {
        let store = profile()
        switch field {
        case .name: return store.name
        case .featured: return ids(store.featuredFiles)
        case .featuredPrompts: return store.featuredPrompts
        case .banner(let month): return ids(store.bannerFiles(for: month))
        case .bannerLayout(let month): return store.bannerLayout(for: month)
        }
    }

    private func ids(_ files: [String]) -> [String]? {
        let mapped = files.compactMap { winForFile($0)?.uuidString }
        // A choice whose wins this phone cannot name is not sent half.
        return mapped.count == files.count ? mapped : nil
    }

    /// Every stamped field this phone is ahead on, into iCloud.
    func push() {
        var remote = cloud.dictionary(forKey: Self.cloudKey) as? [String: [String: Any]] ?? [:]
        var wrote = false
        for (key, stamp) in localStamps {
            guard let field = Field(key: key), stamp > CrewChoicesSync.stamp(remote[key]),
                  let value = localValue(field) else { continue }
            remote[key] = ["v": value, "t": stamp]
            wrote = true
        }
        if wrote {
            cloud.set(remote, forKey: Self.cloudKey)
            cloud.synchronize()
        }
    }

    // MARK: Arrivals

    /// What iCloud holds, onto this phone: every field newer there, or the
    /// same age and now more complete (a win that has since arrived).
    func pull() {
        let remote = cloud.dictionary(forKey: Self.cloudKey) as? [String: [String: Any]] ?? [:]
        var stamps = localStamps
        let store = profile()
        var touchedYou = false
        applying = true
        defer { applying = false }
        for (key, entry) in remote {
            guard let field = Field(key: key) else { continue }
            let theirs = CrewChoicesSync.stamp(entry)
            let mine = stamps[key] ?? -1
            guard theirs >= mine, let value = entry["v"] else { continue }
            switch field {
            case .name:
                guard let name = value as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      name != store.name else { break }
                store.setName(name)
                touchedYou = true
            case .featured:
                guard let ids = value as? [String] else { break }
                let files = files(ids)
                guard files != store.featuredFiles, files.count >= store.featuredFiles.count || theirs > mine else { break }
                store.setFeatured(files)
                touchedYou = true
            case .featuredPrompts:
                guard let prompts = value as? [String], prompts != store.featuredPrompts else { break }
                for (i, p) in prompts.prefix(FeaturedWins.slots).enumerated() { store.setFeaturedPrompt(String(p.prefix(60)), at: i) }
            case .banner(let month):
                guard let ids = value as? [String] else { break }
                let files = files(ids)
                let now = store.bannerFiles(for: month)
                guard files != now, files.count >= now.count || theirs > mine else { break }
                store.setBanner(files, for: month)
            case .bannerLayout(let month):
                guard let index = value as? Int, index != store.bannerLayout(for: month) else { break }
                store.setBannerLayout(index, for: month)
            }
            stamps[key] = max(theirs, mine)
        }
        defaults.set(stamps, forKey: Self.stampsKey)
        if touchedYou { SocialStore.noteMyselfChanged() }
        // Anything only this phone knows goes up.
        push()
    }

    private func files(_ ids: [String]) -> [String] {
        ids.compactMap { UUID(uuidString: $0).flatMap(fileForWin) }
    }

    // MARK: Once

    /// Choices made before sync, stamped as old as can be, so any real change
    /// on another phone wins over them; then sent if iCloud has none.
    func adoptOldChoices() {
        guard defaults.object(forKey: Self.stampsKey) == nil else { return }
        let store = profile()
        var stamps: [String: Double] = [:]
        if !store.name.isEmpty { stamps[Field.name.key] = 1 }
        if !store.featuredFiles.isEmpty { stamps[Field.featured.key] = 1 }
        if defaults.stringArray(forKey: "profileFeaturedPrompts") != nil { stamps[Field.featuredPrompts.key] = 1 }
        for month in store.bannerMonths { stamps[Field.banner(month).key] = 1 }
        for month in store.bannerLayoutMonths { stamps[Field.bannerLayout(month).key] = 1 }
        defaults.set(stamps, forKey: Self.stampsKey)
    }

    private var started = false

    /// Listening for the other phone, and one look now; after that, a look
    /// each time the app comes back.
    func start(store container: ModelContainer) {
        guard !started else {
            cloud.synchronize()
            pull()
            return
        }
        started = true
        useStore(container)
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil, queue: .main) { _ in
            Task { @MainActor in ProfileSync.shared.pull() }
        }
        adoptOldChoices()
        cloud.synchronize()
        pull()
    }

    /// Reset All Data empties the profile everywhere it is kept, iCloud's
    /// copy with it, as the privacy policy says.
    func forget() {
        defaults.removeObject(forKey: Self.stampsKey)
        cloud.set(nil, forKey: Self.cloudKey)
        cloud.synchronize()
    }
}
