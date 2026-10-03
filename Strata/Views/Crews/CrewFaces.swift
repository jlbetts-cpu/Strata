import Observation
import SwiftUI
import UIKit

/// Friends' heads, unpacked once and kept.
///
/// A member's head arrives as one `CrewHeadPack` file; it is unpacked beside
/// it into a folder and loaded with the same reader your own heads use, off
/// the main actor. Your own head is `HeadStore`'s, never a copy.
@MainActor
@Observable
final class CrewHeads {
    static let shared = CrewHeads()

    private(set) var rigs: [String: HeadRig] = [:]
    @ObservationIgnored private var loading: Set<String> = []

    private func key(_ crew: CrewID, _ member: UUID) -> String { "\(crew.rawValue)/\(member.uuidString)" }

    /// The head to draw for a member, or nil (an initial is drawn instead).
    /// Starts the load the first time it is asked for.
    func rig(for member: CrewMember, in crew: CrewID, me: UUID) -> HeadRig? {
        if member.profileID == me { return HeadStore.shared.headForCrews }
        // Keyed by the pack's file as well: a friend who makes a new head
        // sends a new file, and the old rig is not the one to draw.
        let key = key(crew, member.profileID) + "/" + (member.head?.lastPathComponent ?? "")
        if let rig = rigs[key] { return rig }
        guard let pack = member.head, !loading.contains(key) else { return nil }
        loading.insert(key)
        let folder = pack.deletingPathExtension().appending(path: "unpacked", directoryHint: .isDirectory)
        Task.detached(priority: .userInitiated) {
            let rig: HeadRig? = {
                if let loaded = HeadStore.load(at: folder)?.rig { return loaded }
                guard let data = try? Data(contentsOf: pack) else { return nil }
                return try? CrewHeadPack.unpack(data, into: folder)
            }()
            await MainActor.run {
                if let rig { self.rigs[key] = rig }
                self.loading.remove(key)
            }
        }
        return nil
    }

    /// A member changed heads: forget the old one.
    func forget(_ member: UUID, in crew: CrewID) {
        let prefix = key(crew, member) + "/"
        for key in rigs.keys where key.hasPrefix(prefix) { rigs[key] = nil }
    }
}

/// One member, in a circle: their head's still face, or their initial.
struct CrewFace: View {
    let member: CrewMember
    let crew: CrewID
    let me: UUID
    let side: CGFloat

    var body: some View {
        let rig = CrewHeads.shared.rig(for: member, in: crew, me: me)
        ZStack {
            Circle().fill(fill)
            if let rig {
                // **With its eyes.** The face picture alone has empty eye
                // whites: the irises are their own layer, and a circle drawn
                // from the picture stared out with no pupils (the owner,
                // 2026-10-02: "creepy"). `HeadStill` is the head as a still,
                // resting gaze and all, the one every still head uses.
                // Crown to chin fills about nine tenths of the circle, the
                // way a contact photo does.
                HeadStill(rig: rig, side: side * 0.9)
                    .frame(width: side, height: side)
                    .offset(y: side * 0.04)
            } else if let photo = member.photo, let image = UIImage(contentsOfFile: photo.path) {
                // A photograph fills the circle a head sits in, so the two
                // read as one set (Messages' own answer for Memoji beside
                // photos; the owner chose it 2026-10-02).
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(member.initial.isEmpty ? " " : member.initial)
                    .font(.system(size: side * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// A colour of the app's own palette, picked by the person's id so it is
    /// the same on every phone.
    private var fill: Color {
        if CrewHeads.shared.rig(for: member, in: crew, me: me) != nil || member.photo != nil { return AppColors.quietFill }
        let palette = HabitCategory.selectable
        let index = Int(member.profileID.uuid.0) % max(palette.count, 1)
        return palette[index].style.baseColor
    }
}

/// A crew's picture: its photograph, or its people clustered the way Messages
/// clusters a group, in one circle.
///
/// The arrangements are Messages': one face fills it; two sit corner to
/// corner; three are a large face and two smaller ones around it; four and
/// more show four. Everyone but you, because the picture is of who you are
/// with.
struct CrewFaces: View {
    let crew: Crew
    let me: UUID
    var side: CGFloat = 52

    var body: some View {
        ZStack {
            if let photo = crew.photo, let image = UIImage(contentsOfFile: photo.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(AppColors.quietFill)
                // Nobody has joined yet: the crew is you, so far, and its
                // picture is your face rather than an empty circle.
                let others = crew.others(than: me)
                let people = others.isEmpty ? crew.members.filter { $0.profileID == me } : Array(others.prefix(4))
                ForEach(Array(people.enumerated()), id: \.element.id) { index, member in
                    let spot = Self.spot(index, of: people.count)
                    CrewFace(member: member, crew: crew.id, me: me, side: side * spot.size)
                        .overlay(Circle().strokeBorder(AppColors.quietFill, lineWidth: people.count > 1 ? 1.5 : 0))
                        .offset(x: side * spot.x, y: side * spot.y)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// Where face `index` of `count` sits, as fractions of the circle.
    static func spot(_ index: Int, of count: Int) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        switch count {
        case 0, 1: return (0, 0, 1)
        case 2: return [(-0.16, -0.14, 0.56), (0.18, 0.16, 0.5)][index]
        case 3: return [(-0.14, -0.13, 0.5), (0.24, 0.02, 0.36), (-0.02, 0.29, 0.32)][index]
        default: return [(-0.17, -0.17, 0.44), (0.19, -0.15, 0.38), (-0.15, 0.2, 0.38), (0.2, 0.2, 0.34)][index]
        }
    }
}

