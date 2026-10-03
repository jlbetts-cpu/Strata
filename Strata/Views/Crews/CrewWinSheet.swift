import SwiftUI

/// One win in a crew, opened: the block large, whose it is and when.
///
/// A friend's win offers Report and nothing else; your own offers taking it
/// back out of this crew. No likes, no replies: a crew sees wins, it does not
/// grade them.
struct CrewWinSheet: View {
    let win: SharedWin
    let crewID: CrewID

    @Environment(\.dismiss) private var dismiss
    @State private var confirmsReport = false
    @State private var reported = false

    private var store: SocialStore { SocialStore.shared }
    private var isMine: Bool { win.senderProfileID == store.me }
    private var sender: String {
        if isMine { return "Your win" }
        let name = store.crew(crewID)?.member(win.senderProfileID)?.shortName ?? ""
        return name.isEmpty ? "A friend's win" : "\(name)'s win"
    }
    private var crewName: String { store.crew(crewID)?.displayName(excluding: store.me) ?? "this crew" }

    var body: some View {
        VStack(spacing: GridConstants.gapWide) {
            let width: CGFloat = win.blockSize.columnSpan == 2 ? 240 : 140
            let height: CGFloat = win.blockSize.rowSpan == 2 ? 240 : (win.blockSize.columnSpan == 2 ? 120 : 140)
            BlockFace(title: win.title, category: win.colour, rowSpan: win.blockSize.rowSpan,
                      width: width, height: height, cornerRadius: GridConstants.cornerRadius * 1.5,
                      hasPhoto: win.photo != nil) {
                if let photo = win.photo {
                    CrewPhotoView(url: photo, width: width, height: height,
                                  crop: CGPoint(x: win.cropX ?? 0, y: win.cropY ?? 0))
                }
            }
            .padding(.top, GridConstants.gapSection)

            VStack(spacing: 4) {
                Text(sender)
                    .font(Typography.headerMedium)
                    .foregroundStyle(AppColors.inkPrimary)
                Text(win.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
                if isMine, store.pendingCrews(for: win.winID).contains(crewID) {
                    Text("Not sent to \(crewName) yet")
                        .font(Typography.screenSubtitle)
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }

            Spacer(minLength: 0)

            if isMine {
                Button(role: .destructive) {
                    Task { await store.withdraw(winID: win.winID, from: crewID) }
                    dismiss()
                } label: {
                    Text("Remove from \(crewName)")
                        .font(Typography.bodyLarge)
                        .foregroundStyle(.red)
                }
            } else if reported {
                Text("Thanks. We'll take a look.")
                    .font(Typography.screenSubtitle)
                    .foregroundStyle(AppColors.inkSecondary)
            } else {
                Button("Report", role: .destructive) { confirmsReport = true }
                    .font(Typography.bodyLarge)
                    .confirmationDialog("Report this win?", isPresented: $confirmsReport, titleVisibility: .visible) {
                        ForEach(CrewSafety.Reason.allCases) { reason in
                            Button(reason.words) {
                                Task {
                                    await CrewSafety.report(win: win, in: crewID, reason: reason)
                                    reported = true
                                }
                            }
                        }
                    } message: {
                        Text("Your report goes to Sturdy. Nobody in the crew is told.")
                    }
            }
        }
        .padding(.horizontal, GridConstants.horizontalPadding)
        .padding(.bottom, GridConstants.gapWide)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
