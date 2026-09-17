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
        /// This face with its eyes shut, derived from the blink
        /// (`HeadDerivation.lidPatch`).
        var shut: Data? = nil
    }

    /// Everything the maker made, ready to write.
    nonisolated struct Payload: Sendable {
        var faces: [HeadRig.Expression: Face]
        /// The raw blink frame, as captured. Kept: every derived shut face is
        /// made from it.
        var shut: Data?
        var popsIn: Set<HeadRig.Expression> = []
        /// The raised-brows capture as it came, when `faces[.browsUp]` is the
        /// banded one (`HeadDerivation.browBand`).
        var rawBrows: (png: Data, eyes: [HeadRig.Eye])? = nil
        /// False: the blink frame was too far off to use (`HeadDerivation`),
        /// so this head does not blink, not even on the raw frame.
        var blinks = true

        /// The raw blink, when this head may use it.
        var usableShut: Data? { blinks ? shut : nil }

        /// **The creator's kind of face, from these captures**: a shut face
        /// for neutral, raised brows and surprised; brows that change only
        /// the brows when the seam measures clean; and which faces pop in.
        func derived() -> Payload {
            let made = HeadDerivation.derive(faces: faces.mapValues { ($0.png, $0.eyes) }, blink: shut)
            var next = self
            if let brows = made.brows, let raw = faces[.browsUp] {
                next.rawBrows = (raw.png, raw.eyes)
                next.faces[.browsUp] = Face(png: brows.png, eyes: brows.eyes)
            }
            for (expression, png) in made.shut where next.faces[expression] != nil {
                next.faces[expression]?.shut = png
            }
            next.popsIn = made.popsIn
            next.blinks = made.blinks
            return next
        }
    }

    /// Version 3 adds each face's derived shut eyes (`<face>-shut.png`), the
    /// banded brows (`browsUp-banded.png`) and which faces pop in. Migrating
    /// leaves every image a version 2 head wrote byte for byte as it was and
    /// replaces only `head.json`.
    nonisolated struct Manifest: Codable {
        var version = 3
        var contentHeight: CGFloat
        var chin: CGFloat
        var eyes: [String: [HeadRig.Eye]]
        var popsIn: [String]? = nil
        var shutFaces: [String]? = nil
        var bandedBrows: Bool? = nil
        /// False when the blink frame was refused outright.
        var blinks: Bool? = nil
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

    /// The head as every screen draws it: wearing `look`.
    private(set) var head: HeadRig?
    /// The head as it was made, before any look.
    private(set) var undressed: HeadRig?
    /// The film look the head wears everywhere it appears. The owner: "a way
    /// to add the filter to the profile picture head so the user can get
    /// different variety and choice of their head."
    private(set) var look: FilmLook.Kind = .none
    @ObservationIgnored private var dressing: Task<Void, Never>?
    /// **Bumped by every save and delete.** A migration that started before
    /// one of them must not write over the new head or bring back a deleted
    /// one, so it checks this, on the main actor, before it touches disk.
    @ObservationIgnored private(set) var epoch = 0
    private(set) var isProfilePicture: Bool
    private(set) var showsOnMap: Bool
    private(set) var showsCameraSticker: Bool
    private(set) var showsOnTower: Bool

    private enum Key {
        static let picture = "headIsProfilePicture"
        static let map = "headOnMap"
        static let sticker = "headCameraSticker"
        static let tower = "headOnTower"
        static let look = "headLook"
    }

    private init() {
        let defaults = UserDefaults.standard
        isProfilePicture = defaults.bool(forKey: Key.picture)
        showsOnMap = defaults.bool(forKey: Key.map)
        showsCameraSticker = defaults.bool(forKey: Key.sticker)
        showsOnTower = defaults.bool(forKey: Key.tower)
        look = defaults.string(forKey: Key.look).flatMap(FilmLook.Kind.init(rawValue:)) ?? .none
        #if DEBUG
        if DebugHarness.seedsMadeHead { Self.writeMadeHeadFixture() }
        #endif
        let loaded = Self.load()
        undressed = loaded?.rig
        #if DEBUG
        if undressed == nil, DebugHarness.seedsHead { undressed = HeadRig.creator() }
        if let on = DebugHarness.headSwitches {
            isProfilePicture = on.contains("picture")
            showsOnMap = on.contains("map")
            showsCameraSticker = on.contains("camera")
            showsOnTower = on.contains("tower")
        }
        #endif
        head = undressed
        dress()
        if loaded?.needsMigration == true, let directory = Self.directory { migrate(directory) }
    }

    // MARK: - Look

    /// Puts the head in a look, everywhere. The undressed head stays on
    /// screen until the dressed one is ready, which is a fraction of a second
    /// for five small faces.
    func setLook(_ kind: FilmLook.Kind) {
        look = kind
        UserDefaults.standard.set(kind.rawValue, forKey: Key.look)
        dress()
    }

    private func dress() {
        dressing?.cancel()
        guard let undressed else { head = nil; return }
        let chosen = FilmLook.look(look)
        guard chosen.kind != .none else { head = undressed; return }
        dressing = Task { [undressed] in
            let dressed = await Task.detached(priority: .userInitiated) {
                undressed.dressed(in: chosen)
            }.value
            guard !Task.isCancelled else { return }
            head = dressed
        }
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
        epoch &+= 1
        try? manager.removeItem(at: directory)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.write(payload, to: directory)
        let isFirstHead = undressed == nil
        undressed = rig
        head = rig
        dress()
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
        epoch &+= 1
        if let directory = Self.directory { try? FileManager.default.removeItem(at: directory) }
        dressing?.cancel()
        undressed = nil
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
                faces[expression] = HeadRig.Face(image: image, eyes: face.eyes,
                                                 shut: face.shut.flatMap(UIImage.init(data:)))
            }
        }
        // A head not yet derived still blinks on neutral with the raw frame.
        return HeadRig(faces: faces, shut: payload.usableShut.flatMap(UIImage.init(data:)), popsIn: payload.popsIn,
                       contentHeight: contentHeight, chin: chin)
    }

    // MARK: - Files

    private static var directory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "Head", directoryHint: .isDirectory)
    }

    /// `addsOnly`: a file that is already there is left exactly as it is (a
    /// migration adds files beside a version 2 head's; only `head.json` is
    /// replaced).
    nonisolated static func write(_ payload: Payload, to directory: URL,
                                  contentHeight: CGFloat = HeadStore.contentHeight,
                                  chin: CGFloat = HeadStore.chin, addsOnly: Bool = false) throws {
        func put(_ data: Data, _ file: String) throws {
            let url = directory.appending(path: file)
            if addsOnly, FileManager.default.fileExists(atPath: url.path) { return }
            try data.write(to: url, options: .atomic)
        }
        var eyes: [String: [HeadRig.Eye]] = [:]
        for (expression, face) in payload.faces {
            let name = expression == .browsUp && payload.rawBrows != nil ? "browsUp-banded" : expression.rawValue
            try put(face.png, "\(name).png")
            if let shut = face.shut { try put(shut, "\(expression.rawValue)-shut.png") }
            eyes[expression.rawValue] = face.eyes
        }
        if let raw = payload.rawBrows {
            try put(raw.png, "browsUp.png")
            eyes["browsUp-raw"] = raw.eyes
        }
        if let shut = payload.shut { try put(shut, "shut.png") }
        let manifest = Manifest(contentHeight: contentHeight, chin: chin, eyes: eyes,
                                popsIn: payload.popsIn.map(\.rawValue).sorted(),
                                shutFaces: payload.faces.compactMap { $0.value.shut == nil ? nil : $0.key.rawValue }.sorted(),
                                bandedBrows: payload.rawBrows != nil, blinks: payload.blinks)
        try JSONEncoder().encode(manifest).write(to: directory.appending(path: "head.json"), options: .atomic)
    }

    /// What is on disk, and whether it predates derivation.
    nonisolated static func read(from directory: URL) -> (payload: Payload, manifest: Manifest)? {
        guard let data = try? Data(contentsOf: directory.appending(path: "head.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else { return nil }
        let banded = manifest.version >= 3 && manifest.bandedBrows == true
        var faces: [HeadRig.Expression: Face] = [:]
        var bandedMissing = false
        for expression in HeadRig.Expression.allCases {
            var png: Data?
            var eyes = manifest.eyes[expression.rawValue] ?? []
            if expression == .browsUp, banded {
                png = try? Data(contentsOf: directory.appending(path: "browsUp-banded.png"))
                if png == nil {
                    // The banded face has gone: the raw capture, with its own eyes.
                    bandedMissing = true
                    png = try? Data(contentsOf: directory.appending(path: "browsUp.png"))
                    eyes = manifest.eyes["browsUp-raw"] ?? eyes
                }
            } else {
                png = try? Data(contentsOf: directory.appending(path: "\(expression.rawValue).png"))
            }
            guard let png else { continue }
            var face = Face(png: png, eyes: eyes)
            if manifest.version >= 3 {
                face.shut = try? Data(contentsOf: directory.appending(path: "\(expression.rawValue)-shut.png"))
            }
            faces[expression] = face
        }
        var payload = Payload(faces: faces, shut: try? Data(contentsOf: directory.appending(path: "shut.png")))
        if manifest.version >= 3 {
            payload.popsIn = Set((manifest.popsIn ?? []).compactMap(HeadRig.Expression.init(rawValue:)))
            payload.blinks = manifest.blinks ?? true
            if banded, !bandedMissing, let raw = try? Data(contentsOf: directory.appending(path: "browsUp.png")) {
                payload.rawBrows = (raw, manifest.eyes["browsUp-raw"] ?? [])
            }
        }
        return (payload, manifest)
    }

    private static func load() -> (rig: HeadRig?, needsMigration: Bool)? {
        guard let directory, let (payload, manifest) = read(from: directory) else { return nil }
        return (HeadRig(faces: rigFaces(payload), shut: payload.usableShut.flatMap(UIImage.init(data:)),
                        popsIn: payload.popsIn, contentHeight: manifest.contentHeight, chin: manifest.chin),
                manifest.version < 3)
    }

    private nonisolated static func rigFaces(_ payload: Payload) -> [HeadRig.Expression: HeadRig.Face] {
        var faces: [HeadRig.Expression: HeadRig.Face] = [:]
        for (expression, face) in payload.faces {
            guard let image = UIImage(data: face.png) else { continue }
            faces[expression] = HeadRig.Face(image: image, eyes: face.eyes, shut: face.shut.flatMap(UIImage.init(data:)))
        }
        return faces
    }

    /// **A head made before derivation gets it once.** The slow part (deriving
    /// the faces) runs off the main actor; the write and the swap happen back on
    /// it, and only if nothing was saved or deleted in between (`epoch`). The
    /// images a version 2 head wrote are left byte for byte as they were: the
    /// new faces are added beside them and `head.json` moves to version 3.
    private func migrate(_ directory: URL) {
        let started = epoch
        Task {
            guard let prepared = await Task.detached(priority: .utility, operation: {
                Self.prepareMigration(directory)
            }).value else { return }
            guard let rig = Self.finishMigration(prepared, in: directory, startedAt: started, now: epoch) else { return }
            #if DEBUG
            let derived = prepared.derived
            NSLog("[strata-head] migrated a version \(prepared.manifest.version) head: shut on \(derived.faces.compactMap { $0.value.shut == nil ? nil : $0.key.rawValue }.sorted()), pops \(derived.popsIn.map(\.rawValue).sorted()), banded brows \(derived.rawBrows != nil)")
            #endif
            replaceUndressed(rig)
        }
    }

    /// What a migration derived, ready to write.
    nonisolated struct PreparedMigration: Sendable {
        let derived: Payload
        let manifest: Manifest
    }

    /// Off the main actor: read a version 2 head and derive. Writes nothing.
    nonisolated static func prepareMigration(_ directory: URL) -> PreparedMigration? {
        guard let (payload, manifest) = read(from: directory), manifest.version < 3 else { return nil }
        return PreparedMigration(derived: payload.derived(), manifest: manifest)
    }

    /// **On the main actor: write, only if the head is still the one that was
    /// read.** Nil when a save or delete ran since (`now != startedAt`), when
    /// the head on disk is no longer version 2, or when writing failed. The
    /// write goes to a copy of the folder, which then replaces it, so a failure
    /// part way leaves the old head whole.
    static func finishMigration(_ prepared: PreparedMigration, in directory: URL,
                                startedAt: Int, now: Int) -> HeadRig? {
        guard now == startedAt else {
            #if DEBUG
            NSLog("[strata-head] migration dropped: the head was saved or deleted while it ran")
            #endif
            return nil
        }
        let manager = FileManager.default
        guard let (_, onDisk) = read(from: directory), onDisk.version < 3 else { return nil }
        let staging = directory.deletingLastPathComponent().appending(path: "Head-migrating", directoryHint: .isDirectory)
        do {
            try? manager.removeItem(at: staging)
            try manager.copyItem(at: directory, to: staging)
            try write(prepared.derived, to: staging, contentHeight: prepared.manifest.contentHeight,
                      chin: prepared.manifest.chin, addsOnly: true)
            _ = try manager.replaceItemAt(directory, withItemAt: staging)
        } catch {
            try? manager.removeItem(at: staging)
            return nil
        }
        let derived = prepared.derived
        return HeadRig(faces: rigFaces(derived), shut: derived.usableShut.flatMap(UIImage.init(data:)),
                       popsIn: derived.popsIn, contentHeight: prepared.manifest.contentHeight,
                       chin: prepared.manifest.chin)
    }

    private func replaceUndressed(_ rig: HeadRig) {
        undressed = rig
        head = rig
        dress()
    }

    #if DEBUG
    /// **`-strataSeedMadeHead`: a made head on disk, the way a version 2 head
    /// was saved**, built from the creator's bundled faces but through the made
    /// head's path: measured outlines, an iris colour, and a blink and raised
    /// brows that are DIFFERENT frames (shifted a few pixels and relit, as a
    /// frame seconds later would be). Loading it runs the migration.
    /// Written only when there is no head on disk.
    private static func writeMadeHeadFixture() {
        guard let directory, !FileManager.default.fileExists(atPath: directory.appending(path: "head.json").path) else { return }
        writeVersion2Fixture(to: directory)
    }

    /// The fixture's files, anywhere (tests write it to a temporary folder).
    static func writeVersion2Fixture(to directory: URL) {
        func outline(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> [CGPoint] {
            (0..<16).map { i in
                let a = Double(i) / 16 * 2 * .pi
                return CGPoint(x: x + rx * CGFloat(cos(a)), y: y + ry * CGFloat(sin(a)))
            }
        }
        let brown = HeadRig.RGB(r: 0.36, g: 0.23, b: 0.13)
        func eye(_ x: CGFloat, _ y: CGFloat, ry: CGFloat = 0.0192) -> HeadRig.Eye {
            HeadRig.Eye(x: x, y: y, rx: 0.0385, ry: ry, outline: outline(x, y, 0.0385, ry), iris: brown)
        }
        func shifted(_ name: String, dx: CGFloat, dy: CGFloat, light: CGFloat) -> Data? {
            guard let image = UIImage(named: name)?.cgImage else { return nil }
            let w = image.width, h = image.height
            guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let data = context.data else { return nil }
            context.draw(image, in: CGRect(x: dx, y: -dy, width: CGFloat(w), height: CGFloat(h)))
            // Relit as an exposure change: every channel scaled.
            let bytes = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
            for i in 0..<(w * h) {
                let alpha = Double(bytes[i * 4 + 3])
                for c in 0..<3 { bytes[i * 4 + c] = UInt8(min(Double(bytes[i * 4 + c]) * (1 + Double(light)), alpha).rounded()) }
            }
            return context.makeImage().flatMap { UIImage(cgImage: $0).pngData() }
        }
        let neutralEyes = [eye(0.3999, 0.5176), eye(0.6018, 0.5265)]
        var eyes: [String: [HeadRig.Eye]] = [:]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            func put(_ data: Data?, _ file: String) throws {
                guard let data else { return }
                try data.write(to: directory.appending(path: file), options: .atomic)
            }
            try put(UIImage(named: "HeadNeutral")?.pngData(), "neutral.png")
            eyes["neutral"] = neutralEyes
            let blinkShift = DebugHarness.madeHeadBlinkShift
            try put(shifted("HeadNeutralClosed", dx: blinkShift.dx, dy: blinkShift.dy, light: 0.06), "shut.png")
            try put(shifted("HeadNeutralBrowsUp", dx: 1, dy: 0, light: 0.03), "browsUp.png")
            eyes["browsUp"] = neutralEyes.map { var e = $0; e.x += 1.0 / 480; e.outline = outline(e.x, e.y, e.rx, e.ry); return e }
            try put(UIImage(named: "HeadSmile")?.pngData(), "smile.png")
            eyes["smile"] = []
            try put(UIImage(named: "HeadRest")?.pngData(), "surprised.png")
            eyes["surprised"] = [eye(0.4000, 0.5169), eye(0.6041, 0.5269)]
            // The creator's wink photograph has its open eye painted for a
            // drawn iris, so the fixture draws one there.
            try put(UIImage(named: "HeadWink")?.pngData(), "wink.png")
            eyes["wink"] = [eye(0.4000, 0.5169, ry: 0.0172)]
            var manifest = Manifest(contentHeight: 0.785, chin: 0.8988, eyes: eyes)
            manifest.version = 2
            try JSONEncoder().encode(manifest).write(to: directory.appending(path: "head.json"), options: .atomic)
            NSLog("[strata-head] wrote the made-head fixture (version 2)")
        } catch {
            NSLog("[strata-head] could not write the made-head fixture: \(error)")
        }
    }
    #endif
}
