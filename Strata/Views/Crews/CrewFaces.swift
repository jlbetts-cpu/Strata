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
        // Held to the photo rule on this phone (`SocialStore.photoIsShown`,
        // 2026-10-08): a head not yet checked, or flagged, is the initial.
        if let pack = member.head, !SocialStore.shared.photoIsShown(pack) { return nil }
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
            } else if let photo = member.photo, SocialStore.shared.photoIsShown(photo),
                      let image = CrewPictures.image(at: photo) {
                // A photograph fills the circle a head sits in, so the two
                // read as one set (Messages' own answer for Memoji beside
                // photos; the owner chose it 2026-10-02).
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(member.initial.isEmpty ? " " : member.initial)
                    // The app's face and weight, as your own avatar's initial is
                    // (`ProfileAvatar`): this one was SF Rounded Semibold, a
                    // second face and a third weight (rule 7, `docs/ten.md`).
                    .font(.system(size: side * 0.42, weight: Typography.bodyWeight))
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
            if let photo = crew.photo, let image = CrewPictures.image(at: photo) {
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
                        .overlay(Circle().strokeBorder(AppColors.quietFill, lineWidth: people.count > 1 ? GridConstants.strokeDefault : 0))
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

/// A face or a crew's picture, read from disk once rather than on every pass:
/// the crews list and the chat redraw every few seconds while open. Keyed by
/// the file's modification date too, so a picture changed in place is read
/// again rather than shown stale.
@MainActor
enum CrewPictures {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(at url: URL) -> UIImage? {
        let changed = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        let key = "\(url.path)@\(changed?.timeIntervalSince1970 ?? 0)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// **Something new, said with a dot.** One size and one ink in the three
/// places it stands: a crew's row, the Crews button, a crew's chat button.
/// They were 9, 10 and 8 points (rule 1 of `docs/ten.md`, 2026-10-11).
extension AppColors {
    /// **The colour of "something new"** (the owner, 2026-10-13). He liked
    /// coral and asked for it researched, "the most friendly and clean",
    /// then "softer and more premium since our app is so minimal". His pick
    /// from five, side by side in light and dark: terracotta, his coral
    /// muted toward earth. It is still seen and read as well as the brighter
    /// coral the research proposed (#DE5F57): 3.32:1 on the light page and
    /// 4.83:1 on dark, against the 3:1 a mark needs, and a white number on
    /// it 3.52:1, iOS's own red badge's legibility, without its alarm. One
    /// colour in both appearances, and none of the block colours.
    static let notify = Color(hex: 0xC9705F)
    static let notifyUI = UIColor(red: 0xC9 / 255, green: 0x70 / 255, blue: 0x5F / 255, alpha: 1)
}

struct NewsDot: View {
    static let side: CGFloat = 9

    /// **How a dot comes and goes, everywhere** (the owner, 2026-10-13: "make
    /// sure the animation of the notification coming in and out is clean
    /// and minimal"). It grows a little into place, from 60%, on one smooth
    /// curve with no bounce, and it leaves by fading, a beat quicker. With
    /// Reduce Motion it only fades. One motion for the row's dot and the
    /// chat's, where one popped elastically and the other did not move.
    static func motion(reduceMotion: Bool) -> Animation {
        reduceMotion ? GridConstants.crossFade : .smooth(duration: 0.28)
    }

    static func transition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity
            : .asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity),
                          removal: .opacity.animation(.easeOut(duration: 0.18)))
    }
    /// A ring of the page's colour round it, where it sits on a glass button's rim.
    var ringed = false

    /// **A dot drawn by hand** (the owner, 2026-10-13: "make the notification
    /// indicator consistent everywhere and a doodle but like a slight doodle
    /// variation dot"). The one dot for "something new" in the app, on a
    /// crew's row, a crew's chat and the Crews tab (`StrataTab.picture`),
    /// never the system's red badge, which he called terrifying.
    var body: some View {
        DoodleDot()
            .fill(AppColors.notify)
            .frame(width: Self.side, height: Self.side)
            .overlay {
                if ringed {
                    DoodleDot().stroke(WarmBackground.top, lineWidth: GridConstants.strokeDefault)
                        .padding(-GridConstants.strokeDefault / 2)
                }
            }
            .accessibilityHidden(true)
    }
}

/// **A dot as a pen makes one**: round, a touch fuller on one side, its edge
/// never quite a circle. Two slow ripples round the rim, a few percent of
/// the radius, fixed, so every dot in the app is the same mark.
struct DoodleDot: Shape {
    func path(in rect: CGRect) -> Path {
        Path(DoodleDot.cgPath(in: rect))
    }

    /// The same outline for UIKit drawing (the tab's glyph).
    nonisolated static func cgPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let steps = 48
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
            // Within the frame at the widest: the ripples only take away.
            let k = 0.94 + 0.04 * sin(2 * t + 0.7) + 0.02 * sin(3 * t + 2.1)
            let p = CGPoint(x: c.x + cos(t) * r * k, y: c.y + sin(t) * r * k * 0.97)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
