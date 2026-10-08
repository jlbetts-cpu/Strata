import Foundation

/// **What a backup carries besides the wins and the journal** (the
/// 2026-10-08 audit: a restore brought every win back and lost the rest).
/// Your stickers, so a day marked with one and every drawing wearing one still
/// show it; your strips' doodles and stickers; and which strips you developed
/// and the wins you took off them, since Your day shows only developed strips.
///
/// Restoring only ever ADDS, as the rest of the restore does: a sticker or a
/// strip file already here is left alone, a strip already developed stays
/// developed, and a choice made on this phone is never replaced by the file's.
@MainActor
enum BackupKeepsakes {
    /// Your strips' files in the ink folder (`StripDecor`: `strip-me-<day>`).
    static func stripFiles(in ink: InkFiles) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: ink.directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("strip-me-") }
    }

    /// Your stickers' files.
    static func stickerFiles(in store: StickerStore) -> [URL] {
        store.names.map { store.directory.appending(path: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Every day with a strip state of yours, read from `StripKeeping`'s keys.
    static func strips(in defaults: UserDefaults) -> [BackupArchive.ExportStrip] {
        let developedPrefix = "strip.developed.me.", outPrefix = "strip.out.me."
        var byDay: [String: BackupArchive.ExportStrip] = [:]
        for (key, value) in defaults.dictionaryRepresentation() {
            if key.hasPrefix(developedPrefix), (value as? Bool) == true {
                let day = String(key.dropFirst(developedPrefix.count))
                byDay[day, default: .init(day: day, developed: false, excluded: [])].developed = true
            } else if key.hasPrefix(outPrefix), let ids = value as? [String], !ids.isEmpty {
                let day = String(key.dropFirst(outPrefix.count))
                byDay[day, default: .init(day: day, developed: false, excluded: [])].excluded = ids.compactMap(UUID.init)
            }
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    struct Restored: Equatable { var stickers = 0; var stripFiles = 0; var strips = 0 }

    /// Puts what the backup carries back, adding only.
    @discardableResult
    static func restore(_ contents: BackupArchive.Contents, stickers: StickerStore = .shared,
                        ink: InkFiles = .shared, defaults: UserDefaults = .standard) -> Restored {
        var done = Restored()
        let fm = FileManager.default
        try? fm.createDirectory(at: stickers.directory, withIntermediateDirectories: true)
        for name in contents.stickerEntries.keys where InkFiles.isPlainName(name) {
            let target = stickers.directory.appending(path: name)
            guard !fm.fileExists(atPath: target.path),
                  let data = try? contents.keepsake(named: name, in: contents.stickerEntries),
                  (try? data.write(to: target, options: .atomic)) != nil else { continue }
            done.stickers += 1
        }
        let order = contents.document.stickers ?? Array(contents.stickerEntries.keys).sorted()
        stickers.adopt(order)

        for name in contents.stripEntries.keys where InkFiles.isPlainName(name) && name.hasPrefix("strip-me-") {
            guard !ink.exists(name), let data = try? contents.keepsake(named: name, in: contents.stripEntries),
                  (try? ink.write(data, named: name)) != nil else { continue }
            done.stripFiles += 1
        }

        for strip in contents.document.strips ?? [] where !strip.day.isEmpty {
            let developed = "strip.developed.me.\(strip.day)", out = "strip.out.me.\(strip.day)"
            if strip.developed, !defaults.bool(forKey: developed) {
                defaults.set(true, forKey: developed)
                done.strips += 1
            }
            if !strip.excluded.isEmpty, (defaults.stringArray(forKey: out) ?? []).isEmpty {
                defaults.set(strip.excluded.map(\.uuidString).sorted(), forKey: out)
            }
        }
        if let paper = contents.document.stripPaper, StripPaper(rawValue: paper) != nil,
           defaults.string(forKey: "strip.paper.chosen") == nil {
            defaults.set(paper, forKey: "strip.paper.chosen")
        }
        return done
    }
}
