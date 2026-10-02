import SwiftUI

/// Your heads, in a row: the one in use marked, its name under it.
///
/// The owner, 2026-09-23: "I want it so you are able to save multiple heads,
/// like you are able to add your friend's head for instance to your tower
/// instead of yours. I feel like that would add a lot of flavor to an already
/// cool looking application."
///
/// **Deliberately the same shape as `HeadLookPicker`**, which sits one row
/// under it in Profile: the same square of `quietFill` at the block's own
/// corner, the same 2pt ink border on the one that is picked, the same caption
/// under it, the same step back for the ones that are not. Two ways of saying
/// "this one is chosen", ten points apart, would be two things to learn.
///
/// No shadow. A swatch is a picture of a head, not a head standing on
/// something (`CLAUDE.md`, and `docs/design-system-future.md` §6).
///
/// The name is language, so it is SF Rounded and not the drawn face
/// (`design-system-future.md` §2: never set a label in Jaro).
struct HeadPickerRow: View {
    let entries: [HeadStore.Entry]
    let activeID: UUID?
    /// One neutral face per head, read off the main actor by
    /// `HeadStore.swatches()`. A head missing from here has not landed yet.
    let swatches: [UUID: HeadRig]
    /// The active head, which is already in memory, so the one that matters
    /// most is drawn before any reading happens.
    let active: HeadRig?
    /// The name on the Profile page above, if there is one. Only `isGenerated`
    /// reads it: `HeadStore.defaultName` calls the FIRST head after the person
    /// when they have typed a name, so without this the one head the app named
    /// for you is the one head whose name looks chosen.
    var person: String = ""
    let onPick: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `HeadLookPicker`'s swatch, to the point.
    private static let side: CGFloat = 60

    /// How much ink the "this one is chosen" ring is drawn in. See the long
    /// note at its call site for both halves of this; the short version is that
    /// a ring round the only option says nothing, so it is not drawn.
    ///
    /// Not `private`, so `HeadPickerRowTests` can hold the rule without a
    /// simulator — the same reason `isGenerated` is not private.
    static func ringInk(isChosen: Bool, entries: Int) -> Double {
        isChosen && entries > 1 ? 0.55 : 0
    }

    /// Whether this is a name the APP wrote, rather than one somebody typed.
    ///
    /// **Matched on the SHAPE, never on the position in the row.** The obvious
    /// implementation is `name == HeadStore.defaultName(index: i, person:)` for
    /// the tile's index, and it is wrong: `defaultName` numbers off the roster
    /// count at the moment a head is made, and deleting a head renumbers
    /// nothing. Make three heads, delete the second, and "Head 3" is sitting at
    /// index 1 with the app's own name on it.
    ///
    /// Not `private`, so `HeadPickerRowTests` can hold it to the three shapes
    /// `HeadStore` actually produces (`HeadStore.swift`, `firstHeadName` and
    /// `defaultName`) without a screen or a simulator. If `defaultName` ever
    /// grows a fourth shape, that test is what fails.
    static func isGenerated(_ name: String, person: String = "") -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        // "Me", the first head's name when the Profile page has none.
        if trimmed == HeadStore.firstHeadName { return true }
        // The person's own name, which is what `defaultName` calls the first
        // head when Profile HAS one. It is already at the top of this page.
        let who = person.trimmingCharacters(in: .whitespacesAndNewlines)
        if !who.isEmpty, trimmed == String(who.prefix(HeadStore.Roster.nameLimit)) { return true }
        // "Head 2", "Head 3" — every head after the first.
        let parts = trimmed.split(separator: " ")
        return parts.count == 2 && parts[0] == "Head" && Int(parts[1]) != nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // **No "+" tile.** Adding is the labelled row under the switches,
            // and one action with two affordances ten points apart is two
            // things to learn for one thing to do. The row is also reachable
            // without scrolling once there are four heads.
            HStack(alignment: .top, spacing: GridConstants.gapItem) {
                ForEach(entries) { tile($0) }
            }
            .padding(.vertical, GridConstants.gapTight)
        }
    }

    private func tile(_ entry: HeadStore.Entry) -> some View {
        let isChosen = entry.id == activeID
        let radius = GridConstants.blockCornerRadius(forCell: Self.side)
        // The active head comes from memory; every other one waits for its
        // swatch rather than borrowing a face that is not its own.
        let rig = swatches[entry.id] ?? (isChosen ? active : nil)
        return Button {
            guard !isChosen else { return }
            HapticsEngine.tick()
            onPick(entry.id)
        } label: {
            // `gapTight`, not a loose 6. Six is not a rung of the spacing
            // ladder (8 / 12 / 16 / 24 / 32) and it was the only value on
            // either picker that was not, which is the fifth value check 7
            // fails a screen for.
            VStack(spacing: GridConstants.gapTight) {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(AppColors.quietFill)
                    if let rig {
                        HeadStill(rig: rig, side: Self.side * 0.78)
                            .frame(width: Self.side, height: Self.side)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
                }
                .frame(width: Self.side, height: Self.side)
                .overlay {
                    // **0.55 ink, not full strength, and the system's own
                    // stroke width.** `AddWinSheet` settled what a selection
                    // ring is on 2026-10-01: "a full-strength `inkPrimary` ring
                    // is a hard black outline floating off the thing it selects,
                    // the only pure ink ring in the app". These two pickers were
                    // the last places still drawing one, and they draw it around
                    // a photograph of somebody's face, where a hard black
                    // outline reads as a cut-out rather than as a choice.
                    //
                    // It can go quieter here than anywhere else, because this
                    // swatch says "chosen" three times over: the ring, the step
                    // up from 0.94 to full size, and the name under it going
                    // from secondary ink to primary. The ring is the loudest of
                    // the three and it is the one that did not need to be.
                    //
                    // **AND IT IS NOT DRAWN AT ALL WHEN THERE IS ONE HEAD**
                    // (2026-10-01). Photographed with a single entry
                    // (`/tmp/s2/*/h2-head-picker-one.png`, both schemes): the
                    // row is one 60pt tile at the leading edge of a 370pt card
                    // with a ring round it measuring **rgb(128) on the card's
                    // 255, 4.0:1** in light and **rgb(157) on 45, 5.0:1** in
                    // dark. That is the loudest mark in the section, and at one
                    // entry it is answering a question nobody asked: there is no
                    // second head for this one to have been chosen INSTEAD OF.
                    // The paragraph above says the swatch states "chosen" three
                    // times over; at one head all three state it zero times, and
                    // this is the only one of the three that costs ink.
                    //
                    // Nothing is lost. The tile is still the head, and the row
                    // under it still says "Delete This Head". The ring comes
                    // back the moment there is something to choose between,
                    // which is the first moment it means anything.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(AppColors.inkPrimary
                                        .opacity(Self.ringInk(isChosen: isChosen,
                                                              entries: entries.count)),
                                      lineWidth: GridConstants.strokeMedium)
                }
                .scaleEffect(isChosen ? 1 : 0.94)
                .animation(reduceMotion ? nil : GridConstants.motionSnappy, value: isChosen)

                // **Only a name somebody CHOSE is drawn** (cut 14,
                // `docs/copy-audit.md`, 2026-10-01). Out of the box this row
                // read "Me" under a picture of your own face, then "Head 2" and
                // "Head 3" under the next two — a 15pt word under a photograph,
                // saying what the photograph is. The comment twenty lines above
                // already admits the redundancy in the other direction: this
                // swatch says "chosen" three times over, and the name was one
                // of the three.
                //
                // A name somebody typed is a Fact and it is the only thing that
                // tells two friends' heads apart. A name the app made up is a
                // caption repeating the picture. So the test is not "is there a
                // name" but "did anybody choose it", and `isGenerated` is that
                // test.
                //
                // **The row still aligns.** `HStack(alignment: .top)` above, so
                // a tile with a name and a tile without stand on the same line
                // rather than centring against each other, and VoiceOver reads
                // every name regardless (`accessibilityLabel`, below) because a
                // picture of a face is not a label somebody can hear.
                if !Self.isGenerated(entry.name, person: person) {
                Text(entry.name)
                    .font(Typography.headerSmall)
                    // **`inkSecondary` for the ones not chosen, not
                    // `inkQuiet`.** A head's name is text somebody reads, and
                    // `inkQuiet` says in its own doc that it is held to 3:1
                    // rather than 4.5:1 because it is for chevrons, placeholders
                    // and hints. Measured on the built sheet, `inkQuiet`
                    // composites to (136, 136, 136) on a white card, 3.3:1;
                    // `inkSecondary` lands at (97, 97, 97), 6.19:1. The step
                    // down from the chosen name is still plain, 15.1:1 against
                    // 6.19:1, and it is now a step between two legible inks
                    // rather than one into a grey the audit would fail.
                    .foregroundStyle(isChosen ? AppColors.inkPrimary : AppColors.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // A little wider than the square, so a name of two or
                    // three words is cut rather than pushing its neighbour.
                    .frame(width: Self.side + GridConstants.gapItem)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // **The name, and the trait says the rest.** This read
        // "\(entry.name), in use" AND carried `.isSelected`, which VoiceOver
        // already speaks as "selected": the same fact twice inside one
        // element, and `HeadLookPicker` beside it does not do it. The words go
        // rather than the trait, because a trait is also what an assistive
        // technology can act on instead of only read out.
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
    }
}
