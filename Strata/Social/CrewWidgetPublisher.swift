import SwiftUI
import WidgetKit

/// **Writes the crew widget's file** (`CrewWidgetSnapshot`), whenever a crew,
/// its people, today's wins or a head changes.
///
/// Watches `SocialStore` and `CrewHeads` through Observation rather than
/// being called from each place a crew can change: a win arriving by push,
/// a refresh, someone joining, a head finishing unpacking. Anything the
/// publish reads re-arms it, so nothing has to remember to call it.
///
/// **Faces are rendered here, once per face.** The widget cannot read a head
/// pack, and has no `HeadRig` to draw, so each person's still head is
/// rendered as it stands on the crew tower (`PersonHead`, `.standing`) and
/// written as a PNG named for what it shows. An unchanged head keeps its
/// file and is not rendered again.
@MainActor
final class CrewWidgetPublisher {
    static let shared = CrewWidgetPublisher()

    private var last: CrewWidgetSnapshot?
    private var pending: Task<Void, Never>?
    private var started = false

    /// The face's side, in points; rendered at 3x.
    private static let faceSide: CGFloat = 60

    /// Starts watching, and looks again on every later call (each time the
    /// app comes forward): what decides whether a friend's photo may be
    /// shown is not something Observation can see change.
    func start() {
        guard CrewsFlag.isOn else { clear(); return }
        guard !started else { schedule(); return }
        started = true
        watch()
    }

    /// Crews are off on this phone: nothing of a crew stays on the home
    /// screen or in the App Group.
    private func clear() {
        guard let url = CrewWidgetSnapshot.fileURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
        if let faces = CrewWidgetSnapshot.headDirectory { try? FileManager.default.removeItem(at: faces) }
        last = nil
        WidgetCenter.shared.reloadTimelines(ofKind: "StrataCrew")
    }

    private func watch() {
        let snapshot = withObservationTracking {
            build()
        } onChange: { [weak self] in
            Task { @MainActor in self?.schedule() }
        }
        if let snapshot { publish(snapshot) }
    }

    /// A burst of changes (a refresh lands every crew at once) is one write.
    private func schedule() {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            watch()
        }
    }

    private func publish(_ snapshot: CrewWidgetSnapshot) {
        if last == nil { last = CrewWidgetSnapshot.read() }
        guard let last, !snapshot.sameContent(as: last) else { return }
        guard snapshot.write() else { return }
        self.last = snapshot
        sweepFaces(keeping: Set(snapshot.crews.flatMap { $0.members.compactMap(\.face) }))
        WidgetCenter.shared.reloadTimelines(ofKind: "StrataCrew")
    }

    /// The crews as their towers show them today, or nil before the crews
    /// have been read this launch: an empty list then means "not asked yet",
    /// and writing it would blank the widget and sweep every face until the
    /// first refresh lands, or all session when offline (review, 2026-10-14).
    private func build() -> CrewWidgetSnapshot? {
        let store = SocialStore.shared
        guard store.hasFetchedCrews else { return nil }
        let me = store.me
        let crews = store.crews.map { crew -> CrewWidgetSnapshot.Crew in
            // One day for the wins and the file, from the store's clock.
            let day = CrewDay.string(for: store.now(), in: crew.timeZone)
            let today = store.wins(in: crew.id, on: day)
            // `visible`: without anyone you blocked, as the tower draws it,
            // and its name worked out from those people only.
            let shown = store.visible(crew.id) ?? crew
            let members = shown.members
                .sorted { $0.joinedAt < $1.joinedAt }
                .map { member in
                    CrewWidgetSnapshot.Member(
                        id: member.profileID.uuidString,
                        name: member.profileID == me ? "You" : member.shortName,
                        face: face(for: member, in: crew.id, me: me),
                        wins: today.filter { $0.senderProfileID == member.profileID }
                            .sorted { $0.createdAt < $1.createdAt }
                            .map { .init(tier: $0.blockSize.massTier, hex: $0.colour.style.baseHexString) })
                }
            return CrewWidgetSnapshot.Crew(
                id: crew.id.rawValue, name: shown.displayName(excluding: me),
                day: day,
                zone: crew.timeZoneIdentifier, members: members)
        }
        return CrewWidgetSnapshot(crews: crews, updated: Date())
    }

    /// The file holding this person's face, rendered if it is not there yet.
    private func face(for member: CrewMember, in crew: CrewID, me: UUID) -> String? {
        let person = HeadPerson.member(member, crew: crew, me: me)
        let rig = HeadIdentity.rig(for: person)
        guard let directory = CrewWidgetSnapshot.headDirectory else { return nil }
        let isMe = member.profileID == me
        // **A friend's head still unpacking keeps the face it had**, rather
        // than flashing their initial and costing a reload each way.
        if rig == nil, !isMe, let pack = member.head, SocialStore.shared.photoIsShown(pack),
           let kept = lastFace(of: member.profileID) {
            return kept
        }
        // A friend's file is named for their head's record, which a new head
        // changes. Yours is named for the picture itself: your head is
        // dressed in its look a moment after the look is chosen, so a name
        // taken from the setting could be given to the undressed picture.
        if !isMe {
            let what = rig != nil ? member.head?.lastPathComponent ?? "head" : "initial-78-\(member.initial)"
            let name = "\(member.profileID.uuidString)-\(Self.stableHash(what)).png"
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) { return name }
            guard let data = render(person, hasHead: rig != nil) else { return nil }
            return write(data, named: name, in: directory)
        }
        guard let data = render(person, hasHead: rig != nil) else { return nil }
        let name = "\(member.profileID.uuidString)-\(Self.stableHash(data)).png"
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) { return name }
        return write(data, named: name, in: directory)
    }

    private func render(_ person: HeadPerson, hasHead: Bool) -> Data? {
        let renderer = ImageRenderer(content:
            // A round picture a little inside the frame, so a circle reads
            // the same size as a head beside it, crown to chin.
            PersonHead(person: person, side: Self.faceSide * (hasHead ? 1 : 0.78), setting: .standing)
                .frame(width: Self.faceSide, height: Self.faceSide, alignment: .bottom)
                .environment(\.colorScheme, .light))
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }

    private func write(_ data: Data, named name: String, in directory: URL) -> String? {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try? data.write(to: directory.appendingPathComponent(name), options: .atomic)) != nil ? name : nil
    }

    private func lastFace(of profileID: UUID) -> String? {
        let id = profileID.uuidString
        if last == nil { last = CrewWidgetSnapshot.read() }
        return last?.crews.lazy.flatMap(\.members).first { $0.id == id }?.face
    }

    /// Faces nobody is shown with any more: an old head, someone who left.
    private func sweepFaces(keeping: Set<String>) {
        guard let directory = CrewWidgetSnapshot.headDirectory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        for file in files where !keeping.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    /// FNV-1a: the same on every launch, unlike `hashValue`.
    private static func stableHash<Bytes: Sequence>(_ bytes: Bytes) -> String where Bytes.Element == UInt8 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return String(hash, radix: 36)
    }

    private static func stableHash(_ text: String) -> String { stableHash(Array(text.utf8)) }
}
