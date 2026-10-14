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

    /// The head to draw for a member, or nil (the blank head is drawn
    /// instead, `HeadPlaceholder`). Ask `HeadIdentity`, not this, from a
    /// screen.
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

/// One member, in a circle: `PersonHead` for them, still, on the quiet well.
///
/// **A name kept for its callers, nothing more** (2026-10-14). The decision
/// it used to make (head, else their photo, else their initial on a colour)
/// is `HeadIdentity`'s now, and a photograph is never drawn for a person
/// (the owner, 2026-10-14: "remove the option for a pfp"). A friend on an
/// older build who still sends one is the blank head in their colour, like
/// anyone else without a head yet.
///
/// **With its eyes.** A still head is `HeadStill`, irises and resting gaze
/// and all: the face picture alone has empty eye whites, and a circle drawn
/// from it stared out with no pupils (the owner, 2026-10-02: "creepy").
struct CrewFace: View {
    let member: CrewMember
    let crew: CrewID
    let me: UUID
    let side: CGFloat

    var body: some View {
        PersonHead(person: .member(member, crew: crew, me: me), side: side)
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
    /// **The colour of "something new": dusk** (the owner, 2026-10-14: "I
    /// feel like blue should be the notification color just because its
    /// cleaner"; his pick from `docs/notify-blue-research-2026-10-14.md`).
    /// Blue is how Mail and Messages mark unread, without red's alarm. Not
    /// iOS's own blue: that sits a few steps from the Work block's #40A9FF
    /// and on a tab bar reads as the selected tab. Dusk is one value in both
    /// appearances: 4.59:1 on the light page and 3.64:1 on the dark one,
    /// 3.69:1 on the light tab bar, and a white digit on it reads 4.67:1. It
    /// also left terracotta behind, which was nearly the Social block's coral.
    ///
    /// **The tab bar's only** (the owner, 2026-10-13: "a lot of the
    /// notification areas around the crew could be in white or black"):
    /// inside the app a dot is ink (`NewsDot`).
    static let notify = Color(hex: 0x4A72C4)
    static let notifyUI = UIColor(red: 0x4A / 255, green: 0x72 / 255, blue: 0xC4 / 255, alpha: 1)
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

    /// **One dot for "something new"** (the owner, 2026-10-13: "make the
    /// notification indicator consistent everywhere"; drawn by hand until
    /// 2026-10-14, round since: `NewsDotShape`). The one dot in the app, on a
    /// crew's row, a crew's chat and the Crews tab (`StrataTab.picture`),
    /// never the system's red badge, which he called terrifying.
    ///
    /// **In ink**: black on the light page, white on the dark one (the owner,
    /// 2026-10-13, see `AppColors.notify`). Design systems keep a hue for
    /// what is urgent and draw a routine unread mark neutral (PatternFly's
    /// notification badge, Siemens iX's badge); a friend's win is never
    /// urgent. The tab bar's dot keeps its colour, since it is seen from
    /// another tab, and a count lives in the back button as text.
    var body: some View { plain }

    private var plain: some View {
        NewsDotShape()
            .fill(.primary)
            .frame(width: Self.side, height: Self.side)
            .overlay {
                if ringed {
                    NewsDotShape().stroke(WarmBackground.top, lineWidth: GridConstants.strokeDefault)
                        .padding(-GridConstants.strokeDefault / 2)
                }
            }
            .accessibilityHidden(true)
    }
}

/// **A clean round dot** (the owner, 2026-10-14: "can you make the
/// notification actually not doodle lets make it clean"). It was drawn by
/// hand, a rim that wobbled a few percent; a notice is read at a glance,
/// and a true circle is the calmest shape for it. One shape for every dot
/// in the app, in SwiftUI and on the tab's glyph.
struct NewsDotShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(NewsDotShape.cgPath(in: rect))
    }

    /// The same outline for UIKit drawing (the tab's glyph).
    nonisolated static func cgPath(in rect: CGRect) -> CGPath {
        let side = min(rect.width, rect.height)
        return CGPath(ellipseIn: CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side),
                      transform: nil)
    }
}
