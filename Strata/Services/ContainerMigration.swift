import Foundation

enum ContainerMigration {
    private static let migrationKey = "hasCompletedAppGroupMigration"

    /// Call BEFORE creating SharedModelContainer. Copies old SQLite store to App Group if needed.
    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }

        let fileManager = FileManager.default

        // Old location: default SwiftData container
        guard let oldDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            defaults.set(true, forKey: migrationKey)
            return
        }
        let oldStore = oldDir.appendingPathComponent("default.store")

        // New location: App Group container
        guard let newDir = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.JaydenBetts.Strata") else {
            defaults.set(true, forKey: migrationKey)
            return
        }
        let newStore = newDir.appendingPathComponent("default.store")

        // Only migrate if old store exists AND new store doesn't
        guard fileManager.fileExists(atPath: oldStore.path),
              !fileManager.fileExists(atPath: newStore.path) else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        // Copy all SQLite files (main store + WAL + SHM)
        let extensions = ["", "-wal", "-shm"]
        for ext in extensions {
            let oldFile = oldDir.appendingPathComponent("default.store\(ext)")
            let newFile = newDir.appendingPathComponent("default.store\(ext)")
            if fileManager.fileExists(atPath: oldFile.path) {
                try? fileManager.copyItem(at: oldFile, to: newFile)
            }
        }

        defaults.set(true, forKey: migrationKey)
    }
}
