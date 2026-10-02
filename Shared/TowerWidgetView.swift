import SwiftUI
import UIKit
import WidgetKit

/// The warm ground the app stands on, repeated here.
///
/// Written out rather than shared from `WarmBackground`: that view lives in
/// the app target, and reaching across for it would mean compiling a growing
/// slice of the app into a process that has a few hundred milliseconds to
/// draw. Two numbers is the right amount of duplication; the whole view is
/// not. If the ground is ever retuned, it is retuned in two places, which is
/// why both carry this note.
struct WidgetGround: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.129, green: 0.125, blue: 0.118),
                   Color(red: 0.094, green: 0.090, blue: 0.086)]
                : [Color(red: 0.965, green: 0.970, blue: 0.978),
                   Color(red: 0.947, green: 0.955, blue: 0.965)],
            startPoint: .top, endPoint: .bottom)
    }
}

/// The photograph, edge to edge, with a floor under the count.
///
/// **This has to be the container BACKGROUND, not content.** A widget's
/// content sits inside system margins, so a photograph drawn there is a
/// picture with a border round it: "the widget photo doesnt take up the whole
/// small widget box." `containerBackground` is the layer that reaches the
/// corners, and it is what WidgetKit expects a full-bleed widget to use.
struct TowerPhotoBackground: View {
    let snapshot: WidgetSnapshot
    var photoIndex: Int = 0

    private var photo: UIImage? {
        let photos = snapshot.photos
        guard !photos.isEmpty else { return nil }
        return TowerWidgetView.image(named: photos[photoIndex % photos.count])
    }

    var body: some View {
        ZStack {
            WidgetGround()
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                // The count sits ON the picture, so it needs a floor under it
                // or a bright sky eats it. Bottom only, and gone by a third of
                // the way up — a veil over the whole photograph would be the
                // thing the tower's caption veil was dialled back for.
                LinearGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0)],
                    startPoint: .bottom, endPoint: .center)
            }
        }
    }
}


// **ONE FACE, AND THIS VIEW HAD TWO. (2026-10-01)**
//
// The owner: "can you make sure there is one font and not so many font
// weights." Every `.font(` in the app target is SF Pro. Four sites in THIS
// file set `design: .rounded`, which is SF Pro Rounded, a second face
// shipping on the home screen. Worse in context: two sites a few lines away
// go through `StrataFont.size()`, which is already `.default`, so the widget
// set its NUMBERS in SF Pro and its WORDS in SF Pro Rounded side by side in
// one view. Rounded came off the app on 2026-09-23 and the widget did not
// follow, because nothing in the app target compiles this file's type.
//
// **AND THE 13s ARE 15 NOW** (2026-10-01, the type pass). The owner: "no tiny
// thin font anywhere... on everypage the weight should be similar". The app's
// floor is 15 and this file is the only place outside it that still set type,
// so the three 13pt lines — the word beside the count, the empty state's
// sentence, and the lock screen's second line — went with the app's.
//
// **The sizes here are literals and must stay literals**: `Typography` is in
// the app target and this file cannot see it. Measured before raising them, so
// that nothing clips: on the small widget's 170pt face, "Your first win goes
// here" is 165.2pt at 15 Medium and wraps as it already did; on
// `accessoryRectangular` (about 160x72), the longest second line "1611
// altogether" is 106.8pt and the stack is 19 + 1 + 17.9 = 37.9pt tall.
struct TowerWidgetView: View {
    let snapshot: WidgetSnapshot
    /// Which of today's photographs to show — see `TowerProvider.getTimeline`.
    var photoIndex: Int = 0
    /// Forced size, for the renderer that photographs this view.
    ///
    /// `widgetFamily` is read-only in the environment, so there is no way to
    /// ask SwiftUI to lay this out as a lock screen accessory from outside
    /// WidgetKit — and nothing on the build machine can place a widget on a
    /// home screen to see it for real.
    var forcedFamily: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily

    private var family: WidgetFamily { forcedFamily ?? environmentFamily }

    private var photo: UIImage? {
        let photos = snapshot.photos
        guard !photos.isEmpty else { return nil }
        return Self.image(named: photos[photoIndex % photos.count])
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            lockScreen
        default:
            homeScreen
        }
    }

    // MARK: - Home screen

    /// **The photograph IS the widget.**
    ///
    /// It was a small tower with a header over it, which is the app's own
    /// screen shrunk until the blocks were 20pt squares — legible only if you
    /// already knew what they were. The owner, after living with it: "i feel
    /// like the widget should just show the picture and it cycle through and
    /// the number of wins for that day just so its clean."
    ///
    /// That is the better idea and it is not only simpler. A home screen is
    /// read at a glance from arm's length, and a photograph survives that
    /// where a grid of small coloured rectangles does not — and the
    /// photographs are the part of this app nobody else has.
    private var homeScreen: some View {
        // The photograph is the container's background — see
        // `TowerPhotoBackground`. Content that tried to be full-bleed only
        // ever got the inside of the system's margins.
        //
        // **The frame does the aligning, not a `Color.clear` spacer.** With a
        // clear child the stack sized itself to the count and the bottom
        // alignment had nothing to push against, so the number sat on the
        // frame's edge and the numerals' descent was cut off.
        Group {
            if snapshot.photos.isEmpty {
                empty
            } else {
                count
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// Today's number, in the owner's own digits.
    private var count: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(StrataFont.digits(snapshot.today))
                .font(StrataFont.size(30))
                .foregroundStyle(.white)
            Text(snapshot.today == 1 ? "win" : "wins")
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: .black.opacity(0.42), radius: 6, y: 1)
        .accessibilityLabel("\(snapshot.today) wins today")
    }

    /// **Not "no wins yet".** An empty day is the state everybody is in every
    /// morning, and the widget's job then is to be an invitation rather than a
    /// score of zero.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                .foregroundStyle(.tertiary)
                .frame(width: 30, height: 30)
            Text(snapshot.total == 0 ? "Your first win goes here" : "Nothing yet today")
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(14)
    }

    // MARK: - Lock screen

    /// No photograph here: the lock screen renders accessories as a flat
    /// tinted stencil, so a picture arrives as a grey smear.
    private var lockScreen: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(StrataFont.digits(snapshot.today))
                    .font(StrataFont.size(16))
                Text("today")
                    .font(.system(size: 15, weight: .medium, design: .default))
            }
            Text(secondLine)
                .font(.system(size: 15, weight: .medium, design: .default))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Thumbnails out of the group container. A widget draws once and is torn
    /// down, so there is nothing to cache.
    static func image(named file: String) -> UIImage? {
        guard let directory = WidgetSnapshot.photoDirectory else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(file).path)
    }
}

extension TowerWidgetView {
    /// The one extra fact worth a second line, and never a repeat of the
    /// first.
    ///
    /// On day one every win IS today's, so "11 wins / 11 today" says the same
    /// thing twice — the failure the tower's own header was redesigned to
    /// avoid. Day one gets to be day one instead.
    fileprivate var secondLine: String {
        if snapshot.streak > 1 { return "\(snapshot.streak) day streak" }
        if snapshot.today == 0 { return "Add one" }
        if snapshot.today == snapshot.total { return "Day one" }
        return "\(snapshot.total) altogether"
    }
}

// **`TowerMark` and `Color(hex6:)` are deleted** (2026-10-01), 123 lines with
// zero call sites. It drew the tower as bricks when that was the widget's whole
// face; `StrataWidget` and `WidgetPreviewRenderer` both draw
// `TowerPhotoBackground` now, so nothing asked it for a tower. Its private
// packer went with it (`GridPacker.firstFit` stays, because the app's tests pin
// it) and
// so did `Color(hex6:)`, whose only reader was its brick fill.
//
// It also carried this target's only two copies of the 14.7% block corner,
// which is the ratio `StaticTowerView` documents for the app. There are none
// left here, and the widget cannot drift from the app's blocks any more because
// it no longer draws one.

extension WidgetSnapshot {
    /// What the gallery and the placeholder show — a tower that looks like
    /// someone's, not an empty box.
    static let preview = WidgetSnapshot(
        total: 34, today: 2, streak: 5,
        blocks: [
            .init(columns: 1, rows: 1, hex: "0EAD74"),
            .init(columns: 2, rows: 1, hex: "40A9FF"),
            .init(columns: 1, rows: 1, hex: "AF9CFA"),
            .init(columns: 2, rows: 2, hex: "0EAD74"),
            .init(columns: 1, rows: 1, hex: "40A9FF"),
            .init(columns: 1, rows: 2, hex: "AF9CFA"),
            .init(columns: 2, rows: 1, hex: "0EAD74"),
            .init(columns: 1, rows: 1, hex: "40A9FF")
        ],
        updated: Date())
}
