import Foundation
import SwiftData
import SwiftUI

enum ImageMigrationRunner {
    private static let migrationKey = "imageMigrationComplete"

    /// Migrates existing imageData blobs to Documents/strata-images/ files.
    /// Idempotent — only processes logs that have imageData but no imageFileName.
    /// Guarded by AppStorage flag so the full scan runs at most once.
    @MainActor
    static func migrateIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        var descriptor = FetchDescriptor<HabitLog>()
        descriptor.fetchLimit = 500
        guard let logs = try? context.fetch(descriptor) else { return }

        let logsToMigrate = logs.filter { $0.imageData != nil && $0.imageFileName == nil }
        guard !logsToMigrate.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        var count = 0
        for log in logsToMigrate {
            guard let data = log.imageData else { continue }
            do {
                let fileName = try ImageManager.shared.saveData(data, for: log.id)
                log.imageFileName = fileName
                log.imageData = nil
                count += 1

                // Batch save every 20 records
                if count % 20 == 0 {
                    try? context.save()
                }
            } catch {
                // Skip this log — next launch will retry
                continue
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
