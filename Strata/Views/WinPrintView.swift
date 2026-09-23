import SwiftUI

/// **A win, opened.**
///
/// The owner: "we are going to make all the wins look like that... when you
/// click and interact with them."
///
/// **It replaces a form.** Tapping a win used to go straight to
/// `AddWinSheet` in editing mode — four fields about the photograph, with the
/// photograph itself a thumbnail inside them. On an app whose whole premise is
/// looking back at what you did, the first thing a tap should give you is the
/// thing you did. Editing is still one tap away; it is just no longer the only
/// destination.
///
/// Black, like the inside of a folder and like the viewfinder, because a
/// photograph on a lit page competes with the page and a photograph on black
/// does not.
struct WinPrintView: View {
    var title: String
    var day: String
    var win: ScatterWin
    var image: UIImage?
    var crop: CGPoint = .zero
    var onClose: () -> Void = {}
    var onEdit: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    var body: some View {
        ZStack {
            Grey.g950.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)

                WinPrint(image: image, win: win, crop: crop)
                    // The page's own margin, so the print sits on the same
                    // line the folders and the section heading do.
                    .padding(.horizontal, GridConstants.gapWide)
                    // It arrives rather than appearing: a small rise, the
                    // same gesture the row uses when you land on Home.
                    .offset(y: arrived ? 0 : 16)
                    .opacity(arrived ? 1 : 0)

                caption
                Spacer(minLength: 0)
            }
            .padding(.bottom, GridConstants.gapSection)
        }
        .task {
            guard !reduceMotion else { arrived = true; return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { arrived = true }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: GridConstants.gapTight) {
            Text(day)
                .font(Typography.sectionLabel)
                .kerning(Typography.sectionKerning)
                .textCase(.uppercase)
                .foregroundStyle(Grey.g400)
            Spacer()
            GlassIconButton(systemName: "square.and.pencil", tint: .white,
                            accessibilityLabel: "Edit this win", action: onEdit)
            GlassIconButton(systemName: "xmark", tint: .white,
                            accessibilityLabel: "Close", action: onClose)
        }
        .padding(.horizontal, GridConstants.gapWide)
        .padding(.bottom, GridConstants.gapWide)
    }

    @ViewBuilder
    private var caption: some View {
        // **Under the print, never on it.** The owner, about the folder's
        // cards: "the titles shouldn't be on the cards with photos." The same
        // reasoning holds harder here — this is the largest the photograph
        // ever gets, so it is the worst place to write across it.
        if !title.isEmpty {
            Text(title)
                .font(Typography.headerMedium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GridConstants.gapWide)
                .padding(.top, GridConstants.gapLabel)
                .opacity(arrived ? 1 : 0)
        }
    }
}
