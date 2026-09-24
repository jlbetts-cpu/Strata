import UIKit
import ImageIO

/// Taking a photograph back in from a backup.
///
/// **On `ImageManager`, not beside it.** `ImageManager` owns the image
/// directory: it is the only thing that names files in there, the only thing
/// that deletes them, and the only thing that knows `derived/` is a cache rather
/// than a photograph. A restore that wrote into that folder itself would be the
/// second owner of a directory whose first owner has a function documented as
/// "the most dangerous function in the app". So the restore hands the bytes and
/// the name here, and this decides.
extension ImageManager {

    /// What happened to one photograph.
    enum Adoption: Equatable, Sendable {
        /// Written under this name, and nothing was overwritten.
        case written(String)
        /// A file of this name was already on the phone and was LEFT ALONE.
        case alreadyHere(String)
        /// Not written, and why.
        case failed(name: String, reason: String)
    }

    /// Puts one photograph from a backup into the image directory.
    ///
    /// **It never overwrites.** A file name in this app is
    /// `<the log's UUID>_<suffix>.<ext>`, so a name that already exists is the
    /// same photograph of the same win: the copy on the phone is the one the app
    /// has already made derivatives from and is already showing, and the copy in
    /// the zip is at best identical. Preferring the existing file means a
    /// restore cannot damage a photograph, which matters more than the
    /// vanishingly rare case of a local file that went bad. That case has its
    /// own answer — delete the win's photograph and restore again — and it does
    /// not need this path to guess.
    ///
    /// **It decodes before it writes.** A photograph that will not decode is
    /// reported here by name, rather than written and discovered months later as
    /// a block with a grey hole in it.
    ///
    /// - Parameter name: the file name from the backup. Reduced to its last
    ///   path component, so nothing in a zip can aim a write outside this
    ///   folder.
    nonisolated func adopt(_ data: Data, named name: String) -> Adoption {
        let safe = (name as NSString).lastPathComponent
        guard !safe.isEmpty, safe != ".", safe != "..", !safe.hasPrefix(".") else {
            return .failed(name: name, reason: "the backup names it \"\(name)\", which is not a file name")
        }
        guard !data.isEmpty else {
            return .failed(name: safe, reason: "it is empty in the backup")
        }
        let url = imageDirectory.appendingPathComponent(safe)
        if FileManager.default.fileExists(atPath: url.path) {
            return .alreadyHere(safe)
        }
        guard Self.decodes(data) else {
            return .failed(name: safe, reason: "it is not a photograph Strata can open")
        }
        do {
            // `.atomic`: a write interrupted half way leaves no half file for
            // the gallery to try to decode.
            try data.write(to: url, options: .atomic)
        } catch {
            return .failed(name: safe, reason: error.localizedDescription)
        }
        // No derivative is baked here. `migrateDerivatives` is idempotent and
        // recomputes its work list from the directory, so the copies get made
        // on the next launch or on first read, which is exactly what happens to
        // a library that predates derivatives. Baking dozens of them inside a
        // restore would put the slowest work in the app in front of the person
        // waiting to see their wins come back.
        Task { @MainActor in ThumbnailStore.shared.fileArrived(safe) }
        return .written(safe)
    }

    /// Whether these bytes really are an image, by decoding a small one.
    ///
    /// ImageIO rather than `UIImage(data:)`: a `UIImage` can be constructed from
    /// a file whose pixels are damaged and fail later, on the main thread, at
    /// first draw. Asking for a thumbnail forces a real decode now. 64px is
    /// enough to prove the file, and cheap enough to do for every photograph in
    /// a backup.
    nonisolated static func decodes(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return false }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) != nil
    }
}
