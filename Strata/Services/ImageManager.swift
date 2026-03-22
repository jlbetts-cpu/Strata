import UIKit
import ImageIO

final class ImageManager: @unchecked Sendable {
    static let shared = ImageManager()

    private let imageDirectory: URL
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "com.strata.imagemanager.io")

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageDirectory = docs.appendingPathComponent("strata-images", isDirectory: true)

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: imageDirectory.path) {
            try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }

        // Cache limits: 100 thumbnails, ~50MB
        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024
    }

    // MARK: - Save

    /// Resizes and encodes to HEIC (or JPEG fallback), writes to disk.
    /// Returns the generated fileName (e.g. "UUID.heic").
    func save(image: UIImage, for logID: UUID, maxDimension: CGFloat = 1024, quality: CGFloat = 0.80) async throws -> String {
        let heicSupported = Self.isHEICSupported()
        let ext = heicSupported ? "heic" : "jpg"
        let fileName = "\(logID.uuidString).\(ext)"
        let fileURL = imageDirectory.appendingPathComponent(fileName)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ioQueue.async {
                let resized = Self.resizeIfNeeded(image, maxDimension: maxDimension)

                let data: Data?
                if heicSupported {
                    data = Self.encodeHEIC(image: resized, quality: quality)
                } else {
                    data = resized.jpegData(compressionQuality: quality)
                }

                guard let imageData = data else {
                    continuation.resume(throwing: ImageManagerError.compressionFailed)
                    return
                }
                do {
                    try imageData.write(to: fileURL, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return fileName
    }

    // MARK: - HEIC Encoding

    private static func isHEICSupported() -> Bool {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return types.contains("public.heic")
    }

    private static func encodeHEIC(image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.heic" as CFString,
            1,
            nil
        ) else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Load Thumbnail

    /// Returns a downsampled thumbnail from cache or disk. Thread-safe.
    func loadThumbnail(fileName: String, maxWidth: CGFloat) async -> UIImage? {
        let cacheKey = "\(fileName)_\(Int(maxWidth))" as NSString

        // Cache hit
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        // Cache miss — downsample from disk
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        let key = String(cacheKey)
        return await withCheckedContinuation { continuation in
            ioQueue.async { [weak self] in
                guard let thumbnail = Self.downsample(url: fileURL, maxPixelWidth: maxWidth) else {
                    continuation.resume(returning: nil)
                    return
                }
                let cost = Int(thumbnail.size.width * thumbnail.size.height * thumbnail.scale * thumbnail.scale * 4)
                self?.thumbnailCache.setObject(thumbnail, forKey: key as NSString, cost: cost)
                continuation.resume(returning: thumbnail)
            }
        }
    }

    // MARK: - Load Full Image

    /// Loads the full-resolution image from disk with forced background decode.
    /// Not cached — use only for detail/carousel views.
    func loadFullImage(fileName: String) async -> UIImage? {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        return await withCheckedContinuation { continuation in
            ioQueue.async {
                let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
                guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions as CFDictionary) else {
                    continuation.resume(returning: nil)
                    return
                }
                let decodeOptions: [CFString: Any] = [
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, decodeOptions as CFDictionary) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: cgImage))
            }
        }
    }

    // MARK: - Delete

    /// Removes the image file from disk and evicts related cache entries.
    func deleteImage(fileName: String) {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)

        // Evict all cached thumbnails for this fileName
        // NSCache doesn't support enumeration, so we remove known size variants
        for width in [100, 150, 200, 250, 300, 400, 500, 600, 800, 1024] {
            let key = "\(fileName)_\(width)" as NSString
            thumbnailCache.removeObject(forKey: key)
        }
    }

    // MARK: - Exists

    func fileExists(fileName: String) -> Bool {
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Resize

    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestEdge = max(size.width, size.height)
        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - ImageIO Downsample

    private static func downsample(url: URL, maxPixelWidth: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelWidth,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Migration Support

    /// Saves raw JPEG data directly to disk (used by migration runner for existing imageData blobs).
    func saveData(_ data: Data, for logID: UUID) throws -> String {
        let fileName = "\(logID.uuidString).jpg"
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileName
    }
}

// MARK: - Error

enum ImageManagerError: Error {
    case compressionFailed
}
