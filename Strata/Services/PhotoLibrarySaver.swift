import Photos
import UIKit

/// Puts a photograph the app took into the camera roll.
///
/// Until now a shot taken in Strata existed only inside Strata: `ImageManager`
/// writes a 1024px HEIC into the app's own container and nothing else. The app
/// was asking to be your camera without behaving like one.
///
/// Three decisions are load-bearing here.
///
/// **The full-resolution image, not the stored one.** `ImageManager.save`
/// downscales to 1024px at 0.80 quality, which is right for a block on a tower
/// and wrong for a photograph you keep. The only place the full-resolution
/// image exists is `CameraView.fire()`, straight off
/// `photo.fileDataRepresentation()`, so that is the one call site.
///
/// **Add-only authorisation.** `.addOnly` prompts for permission to *write* and
/// never grants read access. The app has no business enumerating your library,
/// so it does not ask to.
///
/// **Only photographs the app took.** A picture chosen through `AddWinSheet`'s
/// photo picker is already in the library; writing it back would duplicate it.
enum PhotoLibrarySaver {

    /// The Settings toggle. Default on: a camera that quietly keeps your photos
    /// is the expected behaviour, and the toggle exists for people who would
    /// rather it did not.
    static let defaultsKey = "savesToCameraRoll"

    static var isEnabled: Bool {
        get {
            // `bool(forKey:)` is false for a key never written, which would
            // make the default off. Register the default instead of guessing.
            UserDefaults.standard.register(defaults: [defaultsKey: true])
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    /// Writes `image` to the camera roll, asking for permission the first time.
    ///
    /// Returns whether it landed. Failure is not surfaced to the user: the win
    /// itself has already saved and the photograph is on its block either way,
    /// so a banner here would report a problem the person cannot act on and
    /// did not ask about.
    @discardableResult
    static func save(_ image: UIImage) async -> Bool {
        guard isEnabled else { return false }

        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { continuation.resume(returning: $0) }
        }
        // `.limited` is a read-access concept and is not returned for add-only,
        // but treat anything that is not an outright grant as a refusal rather
        // than assuming.
        guard status == .authorized || status == .limited else { return false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            return false
        }
    }
}
