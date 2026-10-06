import PencilKit
import SwiftUI

/// **A doodle for a friend's win** (spec section 3, "As a crew reply"): the
/// shared one-pen canvas in a small sheet, and Send. The Reply alert's
/// sibling, so it is reached the same way, from the same row, and says the
/// same thing a reply says about who sees it and how long it lasts.
///
/// Nothing is drawn for you and nothing is chosen: one ink, the eraser, undo.
/// While there is ink on it a swipe does not throw it away; Cancel does.
struct DoodleSheet: View {
    /// Whoever posted the win, by name.
    let owner: String
    /// Hands the drawing back; the panel exports and sends it.
    let send: (PKDrawing) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ink = InkController()

    /// The canvas's shape: a little wider than tall, so the sheet stays small
    /// and the photo it answers still shows above it.
    static let aspect: CGFloat = 4 / 3

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: GridConstants.gapItem) {
                InkCanvas(controller: ink, aspectRatio: Self.aspect)
                Text("Only \(owner) sees it. Doodles clear when the day ends.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, GridConstants.horizontalPadding)
            .padding(.top, GridConstants.gapTight)
            .frame(maxHeight: .infinity, alignment: .top)
            .sheetTitle("Doodle", drawn: false)
            .toolbar {
                InkSheetToolbar(confirm: "Send", confirmDisabled: ink.isEmpty,
                                onCancel: { dismiss() },
                                onConfirm: {
                                    HapticsEngine.lightTap()
                                    send(ink.drawing)
                                    dismiss()
                                })
            }
        }
        .presentationDetents([.height(Self.height)])
        .presentationDragIndicator(.visible)
        .presentationBackground { WarmBackground().ignoresSafeArea() }
        .interactiveDismissDisabled(!ink.isEmpty)
    }

    /// The bar, the canvas at its shape across the page, the controls, the
    /// line, and the home indicator's room.
    private static var height: CGFloat {
        let width = UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2
        return 64 + width / aspect + 52 + 56
    }
}
