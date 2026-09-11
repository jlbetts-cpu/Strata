import Observation
import SwiftUI
import UIKit

/// Who the profile belongs to: a name and a picture, on this phone and nowhere
/// else.
///
/// A singleton because the picture is drawn in two places at once — the
/// Memories header and Profile itself — and both must change the moment it
/// does. Not SwiftData: this is one person's two settings, not
/// a record, and it must survive the store being reset for a test.
@Observable
@MainActor
final class ProfileStore {
    static let shared = ProfileStore()

    private(set) var name: String
    private(set) var photo: UIImage?
    /// The colour behind a head or initials in the profile picture, from the
    /// app's own block palette. Nil is the neutral fill. A photograph fills
    /// the circle, so it has no background to colour.
    private(set) var background: HabitCategory?

    private static let nameKey = "profileName"
    private static let backgroundKey = "profileBackground"
    /// The largest the picture is drawn is 88pt — 264px at 3x. 600 leaves
    /// room without holding a camera-sized image in memory for a circle.
    nonisolated private static let photoSide: CGFloat = 600

    private init() {
        name = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        background = UserDefaults.standard.string(forKey: Self.backgroundKey).flatMap(HabitCategory.init(rawValue:))
        photo = Self.photoURL.flatMap { try? Data(contentsOf: $0) }.flatMap(UIImage.init(data:))
    }

    /// "JB" for "Jayden Betts", in the person's own locale's convention.
    /// Empty when there is no name, so callers can fall back to a glyph.
    var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .abbreviated
        if let components = formatter.personNameComponents(from: trimmed) {
            let abbreviated = formatter.string(from: components)
            if !abbreviated.isEmpty { return abbreviated }
        }
        return String(trimmed.prefix(1)).uppercased()
    }

    func setName(_ newValue: String) {
        name = newValue
        UserDefaults.standard.set(newValue, forKey: Self.nameKey)
    }

    func setBackground(_ colour: HabitCategory?) {
        background = colour
        UserDefaults.standard.set(colour?.rawValue, forKey: Self.backgroundKey)
    }

    /// The fill behind a head or initials.
    var backgroundStyle: AnyShapeStyle {
        background.map { AnyShapeStyle($0.style.baseColor) } ?? AnyShapeStyle(.quaternary)
    }

    /// Initials on the chosen colour: black or white, whichever reads better
    /// against it. Computed from the colour's own value, not picked by eye —
    /// amber takes black, green takes white.
    var initialsInk: Color {
        guard let background else { return .primary.opacity(0.85) }
        let hex = background.style.baseHex
        func channel(_ shift: UInt) -> Double {
            let c = Double((hex >> shift) & 0xFF) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        let againstWhite = 1.05 / (luminance + 0.05)
        let againstBlack = (luminance + 0.05) / 0.05
        return againstBlack > againstWhite ? .black.opacity(0.85) : .white
    }

    /// Stores a picture already squared and sized by `preparedPhotoData`.
    func setPhotoData(_ data: Data) {
        guard let url = Self.photoURL, let image = UIImage(data: data) else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            photo = image
        } catch {
            // Leave the old picture in place rather than show one that is not
            // on disk and would vanish on the next launch.
        }
    }

    /// Deletes Strata's copy. Only ever called from an explicit Remove, or
    /// from Reset All Data.
    func removePhoto() {
        if let url = Self.photoURL { try? FileManager.default.removeItem(at: url) }
        photo = nil
    }

    /// Everything, for Reset All Data — which the privacy policy says removes
    /// every photo, and a profile photo is one.
    func reset() {
        removePhoto()
        setName("")
        setBackground(nil)
    }

    /// A centre-square crop at `photoSide`, as JPEG.
    ///
    /// `nonisolated` so decoding a twelve-megapixel photograph happens off the
    /// main actor: done on it, choosing a picture stalled the sheet.
    nonisolated static func preparedPhotoData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let edge = min(size.width, size.height)
        guard edge > 0 else { return nil }
        // Never upscaled: a small picture stays small rather than going soft.
        let side = min(photoSide, edge)
        let scale = side / edge
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let squared = renderer.image { _ in
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            image.draw(in: CGRect(x: (side - drawn.width) / 2,
                                  y: (side - drawn.height) / 2,
                                  width: drawn.width,
                                  height: drawn.height))
        }
        return squared.jpegData(compressionQuality: 0.85)
    }

    private static var photoURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "Profile", directoryHint: .isDirectory)
            .appending(path: "photo.jpg")
    }
}
