import SwiftUI

/// The picture at the top of Profile: you, as `PersonHead` draws you.
///
/// **Your head, or the blank head where yours will be** (the owner,
/// 2026-10-14: "remove the option for a pfp and make the head making a
/// must"). It used to choose between your head, a photograph, your initials
/// on a colour and a glyph, by a switch; there is one answer now, and it is
/// the one every crew shows of you.
///
/// No rim and no shadow. The disc is the quiet
/// well when none is chosen.
struct ProfileAvatar: View {
    let side: CGFloat

    var body: some View {
        // Expressive: on Profile the head is the subject of the page.
        PersonHead(person: .me, side: side, life: .expressive,
                   setting: .disc(.chosen), traceID: "profile")
    }
}
