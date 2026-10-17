import Foundation
import Testing
@testable import Strata

/// **Your profile on every phone you own** (the owner, 2026-10-16: "the
/// banner was different and some of the key moments weren't there").
@MainActor
@Suite("Profile sync", .serialized)
struct ProfileSyncTests {
    let keys = ["profileName", "profileBannerByMonth", "profileBannerLayoutByMonth", "profileFeatured", "profileFeaturedPrompts"]

    /// The profile's own keys, put back as they were after each test.
    func keeping(_ body: () throws -> Void) rethrows {
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) { UserDefaults.standard.set(value, forKey: key) }
        }
        try body()
    }

    func sync(_ cloud: KeyValueCloud, files: [UUID: String]) -> ProfileSync {
        let sync = ProfileSync(cloud: cloud, defaults: UserDefaults(suiteName: "sync-\(UUID().uuidString)")!)
        sync.fileForWin = { files[$0] }
        sync.winForFile = { file in files.first { $0.value == file }?.key }
        return sync
    }

    @Test("the other phone's newer banner and featured wins land here, by win, as this phone's files")
    func arrives() {
        keeping {
            let a = UUID(), b = UUID(), c = UUID()
            let cloud = MemoryKeyValueCloud()
            let later = Date().timeIntervalSince1970 + 60
            cloud.set(["banner.2026-10": ["v": [a.uuidString, b.uuidString], "t": later],
                       "bannerLayout.2026-10": ["v": 3, "t": later],
                       "featured": ["v": [c.uuidString], "t": later],
                       "name": ["v": "Jayden", "t": later]], forKey: ProfileSync.cloudKey)
            let here = sync(cloud, files: [a: "a.jpg", b: "b.jpg", c: "c.jpg"])
            here.pull()
            #expect(ProfileStore.shared.bannerFiles(for: "2026-10") == ["a.jpg", "b.jpg"])
            #expect(ProfileStore.shared.bannerLayout(for: "2026-10") == min(3, ProfileBanner.layouts.count - 1))
            #expect(ProfileStore.shared.featuredFiles == ["c.jpg"])
            #expect(ProfileStore.shared.name == "Jayden")
        }
    }

    @Test("a win not here yet is waited for, and never written back as a shorter choice")
    func waitsForWins() {
        keeping {
            let a = UUID(), b = UUID()
            let cloud = MemoryKeyValueCloud()
            let stamp = Date().timeIntervalSince1970 + 60
            cloud.set(["banner.2026-09": ["v": [a.uuidString, b.uuidString], "t": stamp]], forKey: ProfileSync.cloudKey)
            ProfileStore.shared.setBanner([], for: "2026-09")
            // Only a has arrived on this phone.
            let here = sync(cloud, files: [a: "a.jpg"])
            here.pull()
            #expect(ProfileStore.shared.bannerFiles(for: "2026-09") == ["a.jpg"])
            let remote = cloud.dictionary(forKey: ProfileSync.cloudKey) as? [String: [String: Any]]
            #expect((remote?["banner.2026-09"]?["v"] as? [String])?.count == 2, "iCloud keeps the whole choice")
            // b arrives: the next pull completes it.
            let later = sync(cloud, files: [a: "a.jpg", b: "b.jpg"])
            later.pull()
            #expect(ProfileStore.shared.bannerFiles(for: "2026-09") == ["a.jpg", "b.jpg"])
        }
    }

    @Test("Reset All Data on one phone clears the other's choices, and nothing older comes back")
    func resetEverywhere() {
        keeping {
            let a = UUID()
            let cloud = MemoryKeyValueCloud()
            let old = Date().timeIntervalSince1970 - 60
            cloud.set(["featured": ["v": [a.uuidString], "t": old]], forKey: ProfileSync.cloudKey)
            let mine = sync(cloud, files: [a: "a.jpg"])
            mine.pull()
            #expect(ProfileStore.shared.featuredFiles == ["a.jpg"])
            // The other phone resets.
            let other = sync(cloud, files: [a: "a.jpg"])
            other.forget()
            mine.pull()
            #expect(ProfileStore.shared.featuredFiles.isEmpty)
            // This phone's older stamps never put it back.
            mine.push()
            let remote = cloud.dictionary(forKey: ProfileSync.cloudKey) as? [String: [String: Any]]
            #expect(remote?["featured"] == nil)
        }
    }

    @Test("a change here goes up, by win id, and an older one there does not overwrite it")
    func goesUp() {
        keeping {
            let a = UUID()
            let cloud = MemoryKeyValueCloud()
            cloud.set(["featured": ["v": [UUID().uuidString], "t": 5]], forKey: ProfileSync.cloudKey)
            let here = sync(cloud, files: [a: "a.jpg"])
            UserDefaults.standard.set(["a.jpg"], forKey: "profileFeatured")
            here.changed(.featured)
            let remote = cloud.dictionary(forKey: ProfileSync.cloudKey) as? [String: [String: Any]]
            #expect(remote?["featured"]?["v"] as? [String] == [a.uuidString])
            here.pull()
            #expect(ProfileStore.shared.featuredFiles == ["a.jpg"])
        }
    }
}
