import SwiftUI

/// Who is drawn.
///
/// **A person is asked for, never a picture** (the owner, 2026-10-14: "treat
/// the head not really as an optional thing but an identity like our version
/// of the bit moji peoples identity"). A screen says who it means and
/// `HeadIdentity` decides what that person looks like, so when heads can be
/// dressed later the dressing is taught to one place, not to twenty call
/// sites (plan: `docs/heads-as-identity-2026-10-14.md` §4.1).
enum HeadPerson {
    /// You, on this phone.
    case me
    /// Somebody in a crew, as this phone sees them. `me` is this phone's
    /// profile id, so a crew's row for you resolves to your own head.
    case member(CrewMember, crew: CrewID, me: UUID)
}

/// **One answer to "what does this person look like"**, where there were two
/// (`ProfileAvatar` for you and `CrewFace` for crews) that could disagree on
/// one screen. Every rule about whose head is drawn lives here.
@MainActor
enum HeadIdentity {
    /// Their head, or nil for the placeholder.
    ///
    /// A friend's goes through `CrewHeads`, which holds the photo check and
    /// the incoming policy; yours is the head your crews receive, so Wins and
    /// a crew can never show two different yous.
    static func rig(for person: HeadPerson) -> HeadRig? {
        switch person {
        case .me:
            return HeadStore.shared.headForCrews
        case let .member(member, crew, me):
            return CrewHeads.shared.rig(for: member, in: crew, me: me)
        }
    }

    static func profileID(of person: HeadPerson) -> UUID {
        switch person {
        case .me: return ProfileStore.profileID
        case let .member(member, _, _): return member.profileID
        }
    }

    /// "S" for Sam. Empty when there is no name: the head is drawn blank.
    static func initial(of person: HeadPerson) -> String {
        switch person {
        case .me: return initial(fromName: ProfileStore.shared.name)
        case let .member(member, _, _): return member.initial
        }
    }

    /// The placeholder's colour.
    static func colour(of person: HeadPerson) -> Color {
        let palette = HabitCategory.selectable
        return palette[paletteIndex(for: profileID(of: person), count: palette.count)].style.baseColor
    }

    /// **Picked by the person's id, so it is the same on every phone**: two
    /// friends with no head yet are still told apart, and you are the same
    /// colour on your phone as on theirs. The rule `CrewFace` used for an
    /// initial's circle, moved here unchanged.
    nonisolated static func paletteIndex(for id: UUID, count: Int) -> Int {
        Int(id.uuid.0) % max(count, 1)
    }

    /// The first letter of the first word, as `CrewMember.initial` reads a
    /// friend's name, so your own placeholder carries the letter your crews
    /// see on theirs.
    nonisolated static func initial(fromName name: String) -> String {
        let first = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").first.map(String.init) ?? ""
        return first.first.map { String($0).uppercased() } ?? ""
    }
}

/// **A person, drawn: their head, or the blank head where theirs will be.**
///
/// The only way a screen draws somebody. The caller says who, how big, how
/// alive and what the head is set in; the head's share of a disc is decided
/// here, once, so a head in a circle is one size of that circle everywhere
/// (the audit found five: 0.76, 0.78, 0.8, 0.9 and 0.92).
struct PersonHead: View {
    let person: HeadPerson
    /// The frame's side. In a disc, the circle; free or standing, the head's
    /// own height, crown to chin, as `LivingHeadView` takes it.
    let side: CGFloat
    var life: Life = .still
    var setting: Setting = .disc()
    /// A tap's expression to play (`HeadTake`), for a head that is alive.
    var take: HeadTake.Played? = nil
    /// **False keeps the placeholder in the head's place while the head is
    /// somewhere else on screen**: the Wins crest while your head is out on
    /// the tower (2026-10-14), so the one head on screen is the one floating.
    var showsHead = true
    /// DEBUG: the name a living head's lines carry under `-strataHeadTrace`.
    var traceID: String? = nil

    enum Life { case still, calm, expressive }

    enum Setting {
        /// On a circle: rows, chat, reactions, the header, Profile.
        case disc(Ground = .quiet)
        /// Nothing under it: the crest, a crew tower's floating heads.
        case free
        /// Free, and standing on something, so it casts the one shadow the
        /// app allows (the map).
        case standing
    }

    /// What a disc is made of.
    enum Ground {
        /// `AppColors.quietFill`, the well a contact photo sits in.
        case quiet
        /// Your Background Colour from Profile, the well when none is chosen.
        case chosen
        /// Nothing: the caller's own glass or colour shows through.
        case clear
    }

    /// **One share for a head in a disc, crown to chin, and a small drop.**
    /// `CrewFace`'s framing, the way a contact photo fills its circle (the
    /// owner chose Messages' answer on 2026-10-02). Profile's 0.76 and the
    /// fan's 0.92 were the same idea at other sizes.
    static let discShare: CGFloat = 0.9
    static let discDrop: CGFloat = 0.04
    /// **A head free inside a ring**: the Wins crest, the sticker button and
    /// the onboarding head page. Not a disc's share: the crest's head is the
    /// same head that flies out to the tower, and `CompanionParking` sizes the
    /// flight off this.
    static let ringShare: CGFloat = 0.76

    var body: some View {
        let rig = showsHead ? HeadIdentity.rig(for: person) : nil
        switch setting {
        case .disc(let ground):
            ZStack {
                if rig != nil {
                    well(ground)
                    face(rig, side: side * Self.discShare)
                        .offset(y: side * Self.discDrop)
                } else {
                    // No head yet: the round picture fills its disc, as a
                    // contact's initials do.
                    face(nil, side: side)
                }
            }
            .frame(width: side, height: side)
            .clipShape(Circle())
            .accessibilityHidden(true)
        case .free:
            face(rig, side: side)
                .accessibilityHidden(true)
        case .standing where rig == nil:
            // A round picture stands on nothing, so it casts nothing: the
            // shadow is a head's alone.
            face(nil, side: side)
                .accessibilityHidden(true)
        case .standing:
            face(rig, side: side)
                // **A contact shadow, because it is standing on something**
                // (CLAUDE.md: no shadows except a head's contact shadow when
                // it stands on something). A soft ellipse under the chin, the
                // map marker's own, at any size.
                .background(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.black.opacity(0.26))
                        .frame(width: side * 0.72, height: side * 0.17)
                        .blur(radius: side * 0.048)
                        .offset(y: side * 0.06)
                }
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func well(_ ground: Ground) -> some View {
        switch ground {
        case .quiet: Circle().fill(AppColors.quietFill)
        case .chosen: Circle().fill(ProfileStore.shared.backgroundStyle)
        case .clear: Color.clear
        }
    }

    @ViewBuilder
    private func face(_ rig: HeadRig?, side s: CGFloat) -> some View {
        Group {
            if let rig {
                switch life {
                case .still:
                    HeadStill(rig: rig, side: s)
                case .calm:
                    LivingHeadView(rig: rig, side: s, liveliness: .calm, take: take, traceID: traceID)
                case .expressive:
                    LivingHeadView(rig: rig, side: s, liveliness: .expressive, take: take, traceID: traceID)
                }
            } else {
                HeadPlaceholder(colour: HeadIdentity.colour(of: person),
                                initial: HeadIdentity.initial(of: person), side: s)
            }
        }
        .frame(width: s, height: s)
    }
}

/// **Someone with no head yet: their colour in a circle, with their
/// initial** (the owner, 2026-10-14: "for the people without a head I think
/// a pfp is okay dont need to shape it like a head"). It was the head
/// maker's outline, filled, a slot in the shape of a person; a plain round
/// picture, as a contact without a photo is, reads as a person who has not
/// made their head rather than as a head that went wrong. Never a
/// photograph and never a drawn face.
///
/// `side` is the circle's diameter.
struct HeadPlaceholder: View {
    let colour: Color
    let initial: String
    let side: CGFloat

    /// The initial, as a share of the circle: `CrewFace`'s own 0.42.
    static let letterShare: CGFloat = 0.42

    var body: some View {
        Circle()
            .fill(colour)
            .frame(width: side, height: side)
            .overlay {
                if !initial.isEmpty {
                    Text(initial)
                        // The app's face and weight: a letter sized to its
                        // circle, so it scales with it rather than with
                        // Dynamic Type.
                        .font(.system(size: side * Self.letterShare, weight: Typography.bodyWeight))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }
}
