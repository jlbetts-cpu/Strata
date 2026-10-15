import SwiftUI

/// **A friend's profile** (the owner, 2026-10-15: "you should be able to see
/// other people's profiles so that needs to look clean and consistent with
/// that"). The top is yours exactly (`ProfileTop`), with their head and name;
/// the figures are only what a crew already shares: their wins this week, in
/// the crews you share, and how many crews you share. Never their score: that
/// is counted from a record only their phone holds, and turning it into a
/// comparison is what the profile research warned against.
///
/// Under it, their wins shared with you, newest first, as small blocks: a
/// press opens the win in its crew.
struct FriendProfileSheet: View {
    let member: CrewMember
    /// The crew the profile was opened from, for the head's own rules.
    let crewID: CrewID
    /// Pushed inside a sheet's own stack (the crew card): the glass back,
    /// not Done.
    var pushed = false

    @Environment(\.dismiss) private var dismiss
    private var store: SocialStore { SocialStore.shared }

    /// The crews you share with them, as this phone sees them.
    private var together: [Crew] {
        store.crews.compactMap { store.visible($0.id) }
            .filter { crew in crew.members.contains { $0.profileID == member.profileID } }
    }

    /// Their wins in those crews, once each, newest first, without anything
    /// you hid.
    private var wins: [SharedWin] {
        var seen: Set<UUID> = []
        return together.flatMap { store.wins(in: $0.id) }
            .filter { $0.senderProfileID == member.profileID && !store.hiddenWins.contains($0.winID) }
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert($0.winID).inserted }
    }

    private var thisWeek: Int {
        let start = Date().addingTimeInterval(-7 * 86_400)
        return wins.filter { $0.createdAt >= start }.count
    }

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: GridConstants.spacing), count: 3)

    var body: some View {
        let shared = together.count
        let name = member.shortName.isEmpty ? "A friend" : member.firstName
        ScrollView {
            VStack(spacing: GridConstants.gapSection) {
                ProfileTop(person: .member(member, crew: crewID, me: store.me), name: name,
                           figures: [ProfileTop.Figure(thisWeek, thisWeek == 1 ? "win this week" : "wins this week"),
                                     ProfileTop.Figure(shared, shared == 1 ? "crew together" : "crews together")])
                if wins.isEmpty {
                    Text("Nothing shared yet.")
                        .font(Typography.headerMedium)
                        .foregroundStyle(AppColors.inkPrimary)
                        .padding(.top, GridConstants.gapSection)
                } else {
                    LazyVGrid(columns: Self.columns, spacing: GridConstants.spacing) {
                        ForEach(wins) { win in
                            Button {
                                HapticsEngine.lightTap()
                                open(win)
                            } label: {
                                FriendWinTile(win: win, showsPhoto: win.photo.map(store.photoIsShown) ?? false)
                            }
                            .buttonStyle(.pressSurface)
                            .accessibilityLabel(win.title.isEmpty ? "A win" : win.title)
                            .accessibilityHint("Opens it in its crew.")
                        }
                    }
                    .padding(.horizontal, GridConstants.horizontalPadding)
                }
            }
            .padding(.bottom, GridConstants.gapPage)
        }
        .background { WarmBackground().ignoresSafeArea() }
        // The name once, under the head, as Contacts writes it: the bar's
        // copy of it said the same word twice. It stays the title for the
        // back button and VoiceOver.
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            if !pushed {
                BareToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticsEngine.lightTap()
                        dismiss()
                    } label: {
                        Text("Done").sheetAction()
                    }
                    .buttonStyle(.pressWord)
                }
            }
        }
        .applying(pushed) { $0.glassBackButton() }
    }

    /// The win, in its crew: the sheet goes, and the crew opens on it, as a
    /// tapped notification opens one.
    private func open(_ win: SharedWin) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: GridConstants.sheetLands)
            CrewRouter.shared.openWin = win.winID
            CrewRouter.shared.open = win.crewID
        }
    }
}

/// One of a friend's wins, as a small square block: its photograph if this
/// phone may show it, otherwise its colour, and its title in the block's
/// own white.
private struct FriendWinTile: View {
    let win: SharedWin
    let showsPhoto: Bool
    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous)
            .fill(win.colour.style.baseColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !win.title.isEmpty {
                    Text(win.title)
                        .font(Typography.headerSmall)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(GridConstants.gapTight)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: GridConstants.cornerRadius, style: .continuous))
            .task(id: win.photo) {
                guard showsPhoto, let url = win.photo else { image = nil; return }
                image = await Task.detached(priority: .userInitiated) { UIImage(contentsOfFile: url.path) }.value
            }
    }
}
