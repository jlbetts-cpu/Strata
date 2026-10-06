import Photos
import UIKit

/// **Today's photographs, for the strip beside the block** (the owner,
/// 2026-10-05: "the images should just be sleekly next to the block and also
/// change depending on the size and you can easily just scroll through
/// horizontally").
///
/// The system's embedded picker was tried first: it needs no permission, but
/// its thumbnails are square with square corners and a white band above them,
/// so a Regular block's neighbours could never be its shape. This reads the
/// library itself, which costs the one standard prompt, and only ever asks
/// for today: newest first, no screenshots, a day that runs to 4am.
enum TodaysPhotos {
    /// Enough to scroll through; a day is rarely more.
    static let limit = 40

    enum Access: Equatable {
        /// Never asked. The strip shows one quiet tile that asks when pressed,
        /// so the prompt only ever follows a tap.
        case notAsked
        case allowed
        case refused
    }

    static var access: Access {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: return .notAsked
        case .authorized, .limited: return .allowed
        default: return .refused
        }
    }

    static func requestAccess() async -> Access {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return access
    }

    /// When "today" began: midnight, or yesterday's midnight before 4am, so
    /// a late evening still looks back on its own day.
    static func dayStart(for now: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: now)
        guard calendar.component(.hour, from: now) < 4 else { return start }
        return calendar.date(byAdding: .day, value: -1, to: start) ?? start
    }

    /// Today's photographs, newest first. `sinceDayStart: false` drops the
    /// date for the simulator, whose sample photographs are years old.
    static func fetch(now: Date = Date(), sinceDayStart: Bool = true) -> [PHAsset] {
        guard access == .allowed else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let screenshot = PHAssetMediaSubtype.photoScreenshot.rawValue
        if sinceDayStart {
            options.predicate = NSPredicate(format: "creationDate >= %@ AND (mediaSubtypes & %d) == 0",
                                            dayStart(for: now) as NSDate, screenshot)
        } else {
            options.predicate = NSPredicate(format: "(mediaSubtypes & %d) == 0", screenshot)
        }
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    /// A tile's picture, filled to its shape.
    static func thumbnail(for asset: PHAsset, size: CGSize, scale: CGFloat) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImage(for: asset, targetSize: target,
                                                  contentMode: .aspectFill, options: options) { image, _ in
                done.resume(returning: image)
            }
        }
    }

    /// The photograph itself, for the block: the long side at the size
    /// `ImageManager` keeps, so nothing is fetched that is thrown away.
    static func full(for asset: PHAsset, maxDimension: CGFloat = 2560) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let longest = CGFloat(max(asset.pixelWidth, asset.pixelHeight))
        let factor = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: CGFloat(asset.pixelWidth) * factor,
                            height: CGFloat(asset.pixelHeight) * factor)
        return await withCheckedContinuation { done in
            PHImageManager.default().requestImage(for: asset, targetSize: target,
                                                  contentMode: .aspectFit, options: options) { image, _ in
                done.resume(returning: image)
            }
        }
    }

    /// Where it was taken, so the block lands on the map there and not where
    /// the phone happened to be when it was logged.
    static func place(of asset: PHAsset) -> WinPlace? {
        guard let location = asset.location else { return nil }
        return WinPlace(latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        accuracy: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil)
    }
}
