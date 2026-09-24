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

    // MARK: - The collection

    /// One head in the collection: what it is called, when it was made, and
    /// where its files are.
    ///
    /// The owner, 2026-09-23: "I want it so you are able to save multiple
    /// heads, like you are able to add your friend's head for instance to your
    /// tower instead of yours."
    ///
    /// `folder` is relative to Application Support, and it is the whole reason
    /// this change is additive. **The one head that existed before the
    /// collection was built keeps `"Head"`**: the folder it has always had,
    /// never moved, renamed or rewritten, so a build from before this change
    /// still finds it exactly where it left it. Every head made since lives in
    /// `"Heads/<id>"`, a folder of its own that nothing else ever writes to.
    nonisolated struct Entry: Codable, Identifiable, Equatable, Sendable {
        var id: UUID
        var name: String
        var created: Date
        var folder: String
    }

    /// Every head, and which one is in use.
    ///
    /// The list is the order they were made in. **Exactly one head is active
    /// whenever there is one to be** (`settle()`): every caller outside this
    /// file asks `HeadStore` for "the head" and gets the active one, so a
    /// collection with nothing active would show all of them a person with no
    /// head while their heads sat on disk.
    ///
    /// Every edit is a `mutating` function here rather than list surgery at
    /// the call site, so the rules above can be tested without a screen, a
    /// simulator or a file (`HeadRosterTests`).
    nonisolated struct Roster: Codable, Equatable, Sendable {
        var version = 1
        var heads: [Entry] = []
        var activeID: UUID?

        var active: Entry? { heads.first { $0.id == activeID } }

        /// **A new head is the one in use.** Making one is itself the request
        /// to use it, which is the reasoning `save` already applies to the
        /// profile picture and the camera sticker.
        mutating func add(_ entry: Entry) {
            heads.append(entry)
            activeID = entry.id
        }

        /// Forgets one head. **When it was the one in use, the head beside it
        /// takes over rather than leaving none**: the next along, or the last
        /// one if this was the end of the row. Returns the entry so the caller
        /// can remove its folder, or nil when there was no such head.
        @discardableResult
        mutating func remove(_ id: UUID) -> Entry? {
            guard let index = heads.firstIndex(where: { $0.id == id }) else { return nil }
            let removed = heads.remove(at: index)
            if activeID == removed.id {
                activeID = (heads.indices.contains(index) ? heads[index] : heads.last)?.id
            }
            return removed
        }

        /// Puts a head in use. A head that is not in the list is ignored
        /// rather than pointed at.
        mutating func use(_ id: UUID) {
            guard heads.contains(where: { $0.id == id }) else { return }
            activeID = id
        }

        /// A name somebody typed. Empty keeps the name it has: the maker's
        /// field arrives pre-filled, and clearing it must not leave a head
        /// with no name at all.
        mutating func rename(_ id: UUID, to name: String) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let index = heads.firstIndex(where: { $0.id == id }) else { return }
            heads[index].name = String(trimmed.prefix(Self.nameLimit))
        }

        /// **Exactly one head is in use whenever there is one to use.**
        /// Anything that loads or edits the list ends here.
        mutating func settle() {
            guard !heads.contains(where: { $0.id == activeID }) else { return }
            activeID = heads.first?.id
        }

        /// Long enough for a name and short enough to draw under a 60pt
        /// square without becoming a sentence.
        static let nameLimit = 40
    }

    /// Every head, and which one is in use. One stored value rather than two,
    /// so the rules above cannot be half applied.
    private(set) var roster = Roster()

    var entries: [Entry] { roster.heads }
    var activeID: UUID? { roster.activeID }
    var activeEntry: Entry? { roster.active }

    /// The head as every screen draws it: wearing `look`. **The active one.**
    /// Every caller written before the collection asks for this and needed no
    /// change.
    private(set) var head: HeadRig?
    /// The active head as it was made, before any look.
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
        // **First launch of this code with a head already on the phone**: the
        // roster file does not exist yet, so `loadedRoster` adopts the folder
        // that is there, where it lies, under the name below. No file inside
        // it is read for the adoption, none is written, moved or renamed, and
        // a build from before this change would still load it unchanged.
        let onDisk = Self.support.map { Self.loadedRoster(in: $0, legacyName: Self.firstHeadName) } ?? Roster()
        roster = onDisk
        // A local, not `activeDirectory`: a computed property is a method call
        // on self, and self is not whole until every stored property is set.
        let directory = Self.directory(of: onDisk.active)
        let loaded = directory.flatMap { Self.load(at: $0) }
        undressed = loaded?.rig
        #if DEBUG
        if undressed == nil, DebugHarness.seedsHead {
            undressed = HeadRig.creator()
            // A row of heads with nothing in it would contradict the head on
            // screen. An empty folder: `resolve` refuses it, so nothing can
            // delete a directory for a head that was never on disk, and
            // `persistRoster` never writes it out.
            // Built whole rather than settled: a mutating call on a stored
            // property needs a self that is not finished being built yet.
            let seeded = Entry(id: UUID(), name: Self.firstHeadName, created: Date(), folder: "")
            roster = Roster(heads: [seeded], activeID: seeded.id)
        }
        if let on = DebugHarness.headSwitches {
            isProfilePicture = on.contains("picture")
            showsOnMap = on.contains("map")
            showsCameraSticker = on.contains("camera")
            showsOnTower = on.contains("tower")
        }
        #endif
        head = undressed
        dress()
        if loaded?.needsMigration == true, let directory { migrate(directory) }
    }

    /// What the head that was here before the collection is called until
    /// somebody renames it. It is his own head, and it is the only one that
    /// can be adopted, so there is nothing to guess.
    nonisolated static let firstHeadName = "Me"

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

    /// **Whether the head is on any surface at all.**
    ///
    /// The look picker asks this before it draws: a row of treatments for a
    /// head that appears nowhere is a control for something that is not
    /// happening, which is the owner's note ("why are the filter picker
    /// always visible").
    var isSomewhere: Bool {
        isProfilePicture || showsOnMap || showsCameraSticker || showsOnTower
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

    /// **Adds a head. It never writes over one that is already there.**
    ///
    /// Every save goes to a folder of its own, named after a fresh id, so the
    /// clear-the-folder-first step this used to need is gone with the problem
    /// it solved (a smile skipped this time leaving last time's smile behind).
    /// The owner's heads are minutes of work over a photograph he may not have
    /// any more, and nothing here can reach a head that already exists.
    ///
    /// `name` nil takes the suggestion, so the maker's existing call site
    /// keeps working unchanged and a head is never nameless.
    func save(_ payload: Payload, name: String? = nil) throws {
        guard let rig = Self.rig(from: payload), let support = Self.support else {
            throw CocoaError(.fileWriteUnknown)
        }
        let id = UUID()
        guard let directory = Self.resolve(folder: Self.folder(for: id), in: support) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let manager = FileManager.default
        epoch &+= 1
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try Self.write(payload, to: directory)
        } catch {
            // A half written head is not a head. Only this save's own folder
            // is removed, and only on this save's own failure.
            try? manager.removeItem(at: directory)
            throw error
        }
        let isFirstHead = roster.heads.isEmpty
        roster.add(Entry(id: id, name: name ?? suggestedName(), created: Date(),
                         folder: Self.folder(for: id)))
        persistRoster()
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

    /// Puts one head in use. Every caller that asks for "the head" gets this
    /// one from here on.
    func use(_ id: UUID) {
        guard id != roster.activeID else { return }
        roster.use(id)
        persistRoster()
        loadActive()
    }

    /// Renames one head. An empty name keeps the one it has.
    func rename(_ id: UUID, to name: String) {
        let before = roster
        roster.rename(id, to: name)
        if roster != before { persistRoster() }
    }

    /// **Removes one head, files and all. It cannot be undone**, which is why
    /// the only caller asks first, by name, in plain words.
    ///
    /// The active head is never left empty: `Roster.remove` promotes the head
    /// beside it.
    func delete(_ id: UUID) {
        let wasActive = roster.activeID == id
        // Bumped only once something is really going: `epoch` aborts a
        // migration in flight, and an id that is not here changes nothing.
        guard let removed = roster.remove(id) else { return }
        epoch &+= 1
        Self.removeFolder(removed)
        persistRoster()
        if wasActive { loadActive() }
        if roster.heads.isEmpty { turnEverySwitchOff() }
    }

    /// **Every head**, for Reset All Data, which is the one caller
    /// (`MainAppView`: "the policy says Reset All Data removes every photo; a
    /// profile photo is one, and a head is made of them"). Nothing else in the
    /// app deletes more than one head at a time.
    func delete() {
        epoch &+= 1
        for entry in roster.heads { Self.removeFolder(entry) }
        roster = Roster()
        persistRoster()
        dressing?.cancel()
        undressed = nil
        head = nil
        turnEverySwitchOff()
    }

    private func turnEverySwitchOff() {
        setProfilePicture(false)
        setShowsOnMap(false)
        setShowsCameraSticker(false)
        setShowsOnTower(false)
    }

    /// Loads whatever is active now, and migrates it if it predates
    /// derivation. The undressed head stays nil rather than stale when a
    /// folder cannot be read: a head on screen that is not the one the row
    /// says is picked would be worse than none.
    private func loadActive() {
        dressing?.cancel()
        guard let directory = activeDirectory, let loaded = Self.load(at: directory) else {
            undressed = nil
            head = nil
            return
        }
        undressed = loaded.rig
        head = loaded.rig
        dress()
        if loaded.needsMigration { migrate(directory) }
    }

    /// What to call the next head before anybody types anything.
    ///
    /// The first is you. After that they are numbered, because guessing whose
    /// head it is would be worse than not guessing, and the maker's field is
    /// pre-filled with this so naming never blocks finishing.
    func suggestedName(person: String = "") -> String {
        Self.defaultName(index: roster.heads.count, person: person)
    }

    nonisolated static func defaultName(index: Int, person: String) -> String {
        guard index > 0 else {
            let trimmed = person.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? firstHeadName : String(trimmed.prefix(Roster.nameLimit))
        }
        return "Head \(index + 1)"
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

    /// The app's own directory. Everything a head owns is inside it, and
    /// `resolve` is what makes that a rule rather than a convention.
    nonisolated static var support: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    /// **The folder the one head has always had.** Nothing moves it, renames
    /// it or writes over it: it is adopted into the collection exactly where
    /// it lies, so a build from before the collection still finds it.
    private static var legacyDirectory: URL? {
        support?.appending(path: legacyFolder, directoryHint: .isDirectory)
    }

    nonisolated static let legacyFolder = "Head"
    /// Where a head made since the collection lives, relative to Application
    /// Support.
    nonisolated static func folder(for id: UUID) -> String { "Heads/\(id.uuidString)" }
    /// The roster file, beside the folders rather than inside any of them, so
    /// no head's folder has a file in it that an older build does not expect.
    nonisolated static let rosterFile = "heads.json"

    /// **A head's folder on disk, and only if it really is inside the app's
    /// own directory.**
    ///
    /// The roster is a JSON file like any other, and deleting a head removes a
    /// whole folder, so a `folder` of `"../../Documents"` must never reach
    /// `removeItem`. Nil refuses: outside Application Support, or Application
    /// Support itself.
    nonisolated static func resolve(folder: String, in support: URL) -> URL? {
        guard !folder.isEmpty else { return nil }
        let base = support.standardizedFileURL
        let candidate = base.appending(path: folder, directoryHint: .isDirectory).standardizedFileURL
        let inside = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard candidate.path != base.path, candidate.path.hasPrefix(inside) else { return nil }
        return candidate
    }

    private var activeDirectory: URL? { Self.directory(of: roster.active) }

    nonisolated static func directory(of entry: Entry?) -> URL? {
        guard let support else { return nil }
        return directory(of: entry, in: support)
    }

    /// The same, against a directory handed in, so the rules can be tested
    /// without the app's real Application Support folder anywhere near it.
    nonisolated static func directory(of entry: Entry?, in support: URL) -> URL? {
        guard let entry else { return nil }
        return resolve(folder: entry.folder, in: support)
    }

    /// Removes one head's folder, through the guard. Returns false when the
    /// folder refused to resolve, in which case nothing on disk was touched.
    @discardableResult
    nonisolated static func removeFolder(_ entry: Entry) -> Bool {
        guard let support else { return false }
        return removeFolder(entry, in: support)
    }

    @discardableResult
    nonisolated static func removeFolder(_ entry: Entry, in support: URL) -> Bool {
        guard let url = resolve(folder: entry.folder, in: support) else { return false }
        try? FileManager.default.removeItem(at: url)
        return true
    }

    // MARK: - The roster file

    nonisolated static func readRoster(in support: URL) -> Roster? {
        guard let data = try? Data(contentsOf: support.appending(path: rosterFile)) else { return nil }
        return try? JSONDecoder().decode(Roster.self, from: data)
    }

    nonisolated static func writeRoster(_ roster: Roster, in support: URL) {
        guard let data = try? JSONEncoder().encode(roster) else { return }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try? data.write(to: support.appending(path: rosterFile), options: .atomic)
    }

    private func persistRoster() {
        guard let support = Self.support else { return }
        // A DEBUG seeded head has no folder on disk and must never reach the
        // file: next launch would show a head whose files do not exist.
        var written = roster
        written.heads = written.heads.filter { !$0.folder.isEmpty }
        written.settle()
        Self.writeRoster(written, in: support)
    }

    /// **The collection as it is on disk, with the head that predates it
    /// adopted.**
    ///
    /// What happens on the first launch of this code, in order:
    ///
    /// 1. There is no `heads.json`, so the list starts empty.
    /// 2. `Head/head.json` exists, so that folder is adopted as one entry,
    ///    named `legacyName`, created on the folder's own date. **Not one file
    ///    inside it is written, moved or renamed**, and the only thing the
    ///    adoption itself looks at is whether `head.json` is there.
    /// 3. It is the only head, so it becomes the active one, and every caller
    ///    that asks `HeadStore` for "the head" gets exactly what it got before.
    /// 4. `heads.json` is written, beside `Head/`, never inside it.
    ///
    /// On a rollback the old build ignores `heads.json` and `Heads/` and reads
    /// `Head/` as it always did, so the head that was there is still there,
    /// byte for byte. Heads made since are in `Heads/` and an old build simply
    /// does not see them; nothing is lost.
    ///
    /// The adoption is not once-only on purpose: an old build that re-made the
    /// head would write `Head/` again, and this picks that up too.
    ///
    /// Entries whose folder refuses to resolve, or whose `head.json` has gone,
    /// are dropped from the LIST. Nothing on disk is removed for them.
    nonisolated static func loadedRoster(in support: URL, legacyName: String) -> Roster {
        var roster = readRoster(in: support) ?? Roster()
        let before = roster
        let manager = FileManager.default
        roster.heads = roster.heads.filter { entry in
            guard let url = resolve(folder: entry.folder, in: support) else { return false }
            return manager.fileExists(atPath: url.appending(path: "head.json").path)
        }
        let legacy = support.appending(path: legacyFolder, directoryHint: .isDirectory)
        if manager.fileExists(atPath: legacy.appending(path: "head.json").path),
           !roster.heads.contains(where: { $0.folder == legacyFolder }) {
            let made = (try? legacy.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            // First in the list: it is the oldest head there can be.
            roster.heads.insert(Entry(id: UUID(), name: legacyName, created: made, folder: legacyFolder), at: 0)
        }
        roster.settle()
        if roster != before { writeRoster(roster, in: support) }
        return roster
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
        // Only the shut faces the manifest names, and none on a head whose
        // blink was refused: a stray `<face>-shut.png` left in the folder must
        // never give a face a blink it was not derived to have.
        let shutFaces: Set<String> = manifest.version >= 3 && manifest.blinks != false
            ? Set(manifest.shutFaces ?? [])
            : []
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
            if shutFaces.contains(expression.rawValue) {
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

    nonisolated static func load(at directory: URL) -> (rig: HeadRig?, needsMigration: Bool)? {
        guard let (payload, manifest) = read(from: directory) else { return nil }
        return (HeadRig(faces: rigFaces(payload), shut: payload.usableShut.flatMap(UIImage.init(data:)),
                        popsIn: payload.popsIn, contentHeight: manifest.contentHeight, chin: manifest.chin),
                manifest.version < 3)
    }

    /// **One head's neutral face and nothing else**, for a swatch in the row
    /// in Profile.
    ///
    /// Two files, not the folder: a head is five 600px PNGs and their shut
    /// twins, and a row of five heads that loaded all of them would decode
    /// fifty pictures to draw five 60pt squares. Undressed, because dressing
    /// every swatch again on every look change is work nobody asked for and
    /// the look is already shown, full size, one row above.
    nonisolated static func neutralRig(at directory: URL) -> HeadRig? {
        guard let data = try? Data(contentsOf: directory.appending(path: "head.json")),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              let png = try? Data(contentsOf: directory.appending(path: "\(HeadRig.Expression.neutral.rawValue).png")),
              let image = UIImage(data: png) else { return nil }
        return HeadRig(faces: [.neutral: HeadRig.Face(image: image,
                                                      eyes: manifest.eyes[HeadRig.Expression.neutral.rawValue] ?? [])],
                       contentHeight: manifest.contentHeight, chin: manifest.chin)
    }

    /// Every head's neutral face, read off the main actor, for the row in
    /// Profile.
    func swatches() async -> [UUID: HeadRig] {
        guard let support = Self.support else { return [:] }
        let folders: [(UUID, URL)] = roster.heads.compactMap { entry in
            Self.resolve(folder: entry.folder, in: support).map { (entry.id, $0) }
        }
        guard !folders.isEmpty else { return [:] }
        return await Task.detached(priority: .userInitiated) {
            var made: [UUID: HeadRig] = [:]
            for (id, url) in folders {
                if let rig = Self.neutralRig(at: url) { made[id] = rig }
            }
            return made
        }.value
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
            // **Only if that head is still the one in use.** Switching heads
            // does not bump `epoch` (nothing was written), so without this a
            // migration finishing after a switch would put the head you
            // switched AWAY from back on screen.
            guard activeDirectory == directory else { return }
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
        // Named after the folder being migrated, so two heads can never stage
        // into the same place. For the one head that predates the collection
        // that is still `Head-migrating`.
        let staging = directory.deletingLastPathComponent()
            .appending(path: "\(directory.lastPathComponent)-migrating", directoryHint: .isDirectory)
        do {
            try? manager.removeItem(at: staging)
            try manager.copyItem(at: directory, to: staging)
            // Only what a version 2 head wrote goes forward. Anything else in
            // the folder (a stale `*-shut.png` or banded brows from some earlier
            // run) is removed from the copy, so `addsOnly` cannot keep it.
            let version2 = Set(HeadRig.Expression.allCases.map { "\($0.rawValue).png" } + ["shut.png", "head.json"])
            for name in try manager.contentsOfDirectory(atPath: staging.path) where !version2.contains(name) {
                try manager.removeItem(at: staging.appending(path: name))
            }
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
        guard let directory = legacyDirectory,
              !FileManager.default.fileExists(atPath: directory.appending(path: "head.json").path) else { return }
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
