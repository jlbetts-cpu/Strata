import SwiftUI

/// **The month drawing's second way in** (spec section 4, "The same action
/// also sits in Settings"; NN/g: a hidden gesture needs another path to the
/// same action, and Apple added a Settings path to Lock Screen editing in
/// iOS 16.1 for the same reason). This month's drawing, as Memories shows
/// it, and the same two actions the hold offers, in the same words.
struct MonthDrawingSettingsView: View {
    @State private var editing: DrawingMonth?

    private var month: String {
        MonthDrawingStore.key(for: Date(), calendar: MemoriesViewModel.mondayCalendar)
    }

    var body: some View {
        let own = MonthDrawingStore.shared.drawing(for: month)
        Form {
            Section {
                preview(own)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GridConstants.gapItem)
            }
            Section {
                Button {
                    HapticsEngine.lightTap()
                    MonthDrawingTip.used()
                    editing = DrawingMonth(id: month)
                } label: {
                    // **Words only, as Settings is** (2026-10-07, Settings'
                    // "A row's words"). His drawn pencil was tried here and
                    // came out a hairline beside the word at a row's 13pt,
                    // on a page you reach from a Settings with no glyphs.
                    Text("Draw Your Own").foregroundStyle(AppColors.inkPrimary)
                }
                if own != nil {
                    Button(role: .destructive) {
                        HapticsEngine.lightTap()
                        MonthDrawingStore.shared.remove(month)
                    } label: {
                        Text("Use Original").foregroundStyle(AppColors.destructiveInk)
                    }
                }
            }
        }
        .listSectionSpacing(GridConstants.gapPage)
        .scrollContentBackground(.hidden)
        .background { WarmBackground().ignoresSafeArea() }
        .sheetTitle(MonthName.of(month), drawn: false)
        .fullScreenCover(item: $editing) { which in
            MonthDrawingEditor(month: which.id, monthName: MonthName.of(which.id))
        }
    }

    /// Yours, still, or the owner's for the month, or nothing yet.
    @ViewBuilder
    private func preview(_ own: MonthDrawing?) -> some View {
        if let own, let url = MonthDrawingStore.shared.pictureURL(for: month) {
            InkImage(url: url, scale: JournalSketches.scale)
                .frame(height: 220)
                .accessibilityLabel("Your drawing for the month")
                .id(own.picture)
        } else if let art = UIImage(named: "Month" + MonthName.of(month)) {
            Image(uiImage: art)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColors.drawingInk)
                .frame(height: 220)
                .accessibilityLabel("The month's drawing")
        }
    }
}
