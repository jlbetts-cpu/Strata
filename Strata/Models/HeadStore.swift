import Observation
import UIKit

/// Your head: made once in Profile, kept on this phone, drawn only where you
/// switch it on.
///
/// **Every switch starts OFF.** The head is 100% optional — the owner's call
/// — so somebody who never makes one must never see a gap where it would
/// have been. Plan and reasoning: `docs/profile-and-head-plan.md` §5.
@Observable
@MainActor
final class HeadStore {
    static let shared = HeadStore()

    /// One made face, as saved: a PNG with transparency and its eyes.
    nonisolated struct Face: Sendable {
        var png: Data
        var eyes: [HeadRig.Eye]
    }

    /// Everything the maker made, ready to write.
    nonisolated struct Payload: Sendable {
        var faces: [HeadRig.Expression: Face]
        var shut: Data?
    }

    private nonisolated struct Manifest: Codable {
        var version = 2
        var contentHeight: CGFloat
        var chin: CGFloat
        var eyes: [String: [HeadRig.Eye]]
    }

    /// How much of the square canvas, crown to chin, a made head fills. The
    /// maker crops every face to this, so a placement sizes a head by its face
    /// rather than its file.
    nonisolated static let contentHeight: CGFloat = 0.86
    /// Where the chin sits, from the top. What a head stands on is measured
    /// from here.
    nonisolated static let chin: CGFloat = 0.93
    /// Pixels on a side. The largest a head is drawn is the maker's preview at
    /// 200pt — 600px at 3x.
    nonisolated static let side: CGFloat = 600

    private(set) var head: HeadRig?
    private(set) var isProfilePicture: Bool
    private(set) var showsOnMap: Bool
    private(set) var showsCameraSticker: Bool
    private(set) var showsOnTower: Bool

    private enum Key {
        static let picture = "headIsProfilePicture"
        static let map = "headOnMap"
        static let sticker = "headCameraSticker"
        static let tower = "headOnTower"
    }

    private init() {
        let defaults = UserDefaults.standard
        isProfilePicture = defaults.bool(forKey: Key.picture)
        showsOnMap = defaults.bool(forKey: Key.map)
        showsCameraSticker = defaults.bool(forKey: Key.sticker)
        showsOnTower = defaults.bool(forKey: Key.tower)
        head = Self.load()
        #if DEBUG
        if head == nil, DebugHarness.seedsHead { head = HeadRig.creator() }
        if let on = DebugHarness.headSwitches {
            isProfilePicture = on.contains("picture")
            showsOnMap = on.contains("map")
            showsCameraSticker = on.contains("camera")
            showsOnTower = on.contains("tower")
        }
        #endif
    }

    // MARK: - Switches

    // No `didSet` on these: a property observer on an `@Observable` stored
    // property is where the macro's accessors and the observer meet, and
    // `CameraService` records it as a combination not to rely on.

    func setProfilePicture(_ on: Bool) {
        isProfilePicture = on
        UserDefaults.standard.set(on, forKey: Key.picture)
    }

    func setShowsOnMap(_ on: Bool) {
        showsOnMap = on
        UserDefaults.standard.set(on, forKey: Key.map)
    }

    func setShowsCameraSticker(_ on: Bool) {
        showsCameraSticker = on
        UserDefaults.standard.set(on, forKey: Key.sticker)
    }

    func setShowsOnTower(_ on: Bool) {
        showsOnTower = on
        UserDefaults.standard.set(on, forKey: Key.tower)
    }

    /// A head exists AND its switch is on. Callers ask this rather than the
    /// switch, so deleting the head can never leave a switch pointing at
    /// nothing.
    var headForPicture: HeadRig? { isProfilePicture ? head : nil }
    var headForMap: HeadRig? { showsOnMap ? head : nil }
    var headForSticker: HeadRig? { showsCameraSticker ? head : nil }
    var headForTower: HeadRig? { showsOnTower ? head : nil }

    // MARK: - Saving

    func save(_ payload: Payload) throws {
        guard let rig = Self.rig(from: payload), let directory = Self.directory else {
            throw CocoaError(.fileWriteUnknown)
        }
        let manager = FileManager.default
        // Clear first, so a smile skipped this time does not leave last
        // time's smile behind.
        try? manager.removeItem(at: directory)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        for (expression, face) in payload.faces {
            try face.png.write(to: directory.appending(path: "\(expression.rawValue).png"), options: .atomic)
        }
        if let shut = payload.shut {
            try shut.write(to: directory.appending(path: "shut.png"), options: .atomic)
        }
        let manifest = Manifest(contentHeight: Self.contentHeight, chin: Self.chin,
                                eyes: Dictionary(uniqueKeysWithValues: payload.faces.map { ($0.key.rawValue, $0.value.eyes) }))
        try JSONEncoder().encode(manifest).write(to: directory.appending(path: "head.json"), options: .atomic)

        let isFirstHead = head == nil
        head = rig
        // Making a head is itself the request to use it: as your picture, and
        // as a sticker you can add to a photo (it still takes a press each
        // time). The map and the tower put it somewhere without asking each
        // time, so those stay off until switched on.
        if isFirstHead {
            setProfilePicture(true)
            setShowsCameraSticker(true)
        }
    }

    /// Removes the files and turns every switch off.
    func delete() {
        if let directory = Self.directory { try? FileManager.default.removeItem(at: directory) }
        head = nil
        setProfilePicture(false)
        setShowsOnMap(false)
        setShowsCameraSticker(false)
        setShowsOnTower(false)
    }

    nonisolated static func rig(from payload: Payload) -> HeadRig? {
        var faces: [HeadRig.Expression: HeadRig.Face] = [:]
        for (expression, face) in payload.faces {
            if let image = UIImage(data: face.png) {
                faces[expression] = HeadRig.Face(image: image, eyes: face.eyes)
            }
        }
        return HeadRig(faces: faces, shut: payload.shut.flatMap(UIImage.init(data:)),
                       contentHeight: contentHeight, chin: chin)
    }

    // MARK: - Files

    private static var directory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "Head", directoryHint: .isDirectory)
    }

    private static func load() -> HeadRig? {
        guard let directory,
              let data = try? Data(contentsOf: directory.appending(path: "head.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }
        var faces: [HeadRig.Expression: HeadRig.Face] = [:]
        for expression in HeadRig.Expression.allCases {
            let path = directory.appending(path: "\(expression.rawValue).png").path
            guard let image = UIImage(contentsOfFile: path) else { continue }
            faces[expression] = HeadRig.Face(image: image, eyes: manifest.eyes[expression.rawValue] ?? [])
        }
        return HeadRig(faces: faces,
                       shut: UIImage(contentsOfFile: directory.appending(path: "shut.png").path),
                       contentHeight: manifest.contentHeight, chin: manifest.chin)
    }
}
