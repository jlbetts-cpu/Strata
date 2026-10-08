import Foundation
import SwiftData

/// **A win's photograph, as iCloud carries it** (2026-10-08, the owner: "the
/// photographs must back up too, not only the wins. A design where a restored
/// phone shows the tower with blocks that have lost their pictures is not
/// acceptable").
///
/// The wins already sync, because the store mirrors to the private CloudKit
/// database. The photographs did not: they are files in `strata-images/`,
/// named by `HabitLog.imageFileName`, and a file is not a row. This is the row.
/// It holds a smaller copy of the picture (`WinPhotoPayload`, 1600px) whose
/// bytes CloudKit sends as an asset, under the same `fileName` the log
/// carries, which is the key that puts the picture back on its block on a new
/// phone (`WinPhotoStore.materialise`).
///
/// **The file on disk stays the read path.** Nothing in the app reads `data`
/// to draw. `ImageManager`, the map, the viewer and the replay exporter all
/// read files, and they keep reading the 2560px original on the phone that
/// took it. On a phone that only has the iCloud copy, the copy is written out
/// as the file and the app reads that.
///
/// **Its own model rather than a field on `HabitLog`**, for the reason in
/// `docs/research/icloud-backup.md` section 5.1: a win's record is a few
/// hundred bytes and must keep going up when a picture cannot, and two
/// records fail apart where one record fails whole. It also keeps the bytes
/// out of every `HabitLog` fetch, and the app fetches logs constantly.
///
/// **`nonisolated`, unlike every other model**, so that the materialiser can
/// read it on a context of its own off the main actor. It holds a name, some
/// bytes and a date, and nothing about it is drawn, so there is nothing for
/// the main actor to protect. `HabitLog` stays main-actor, which is why the
/// relationship and its inverse are declared on `HabitLog`'s side.
///
/// Every property is optional or defaulted and nothing is unique, because the
/// CloudKit mirror refuses anything else (`StoreSchemaRules`). Two devices
/// that both make a row for one file is possible in principle and harmless in
/// effect: the materialiser writes the file once and never again.
@Model
nonisolated final class WinPhoto {
    var id: UUID = UUID()
    /// The file this picture belongs under, byte for byte the string
    /// `HabitLog.imageFileName` carries.
    var fileName: String = ""
    /// The picture, at `WinPhotoPayload.maxDimension`. External storage keeps
    /// it out of the row, and the mirror sends it as a CKAsset, which does not
    /// count toward CloudKit's 1MB record limit.
    @Attribute(.externalStorage) var data: Data?
    /// When these bytes were made, so the newest can go first.
    var createdAt: Date = Date()
    /// The win this is the picture of. The inverse, and the cascade that makes
    /// deleting a win delete this (and so its iCloud copy), are on
    /// `HabitLog.photo`.
    var log: HabitLog?

    init(fileName: String, data: Data?, createdAt: Date = Date()) {
        self.fileName = fileName
        self.data = data
        self.createdAt = createdAt
    }
}
