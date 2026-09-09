import SwiftUI
import SwiftData

/// Every day with a photograph, oldest reachable, in weeks.
///
/// The Memories lowfi has only a carousel. Taken literally that would put the
/// whole record behind twenty-odd cards and make anything older unreachable —
/// which is the opposite of what this tab exists for. So the paged grid that
/// used to BE the History screen survives here, one tap away, and the shelf
/// stays the shape the design asked for.
struct AllAlbumsView: View {
    @Bindable var vm: MemoriesViewModel
    let onOpenDay: (String) -> Void

    @Environment(\.modelContext) private var modelContext

    private let columns = [
        GridItem(.flexible(), spacing: 24, alignment: .top),
        GridItem(.flexible(), spacing: 24, alignment: .top)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                searchField
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.top, 6)
                albums
            }
            .padding(.bottom, 110)
        }
        .background { WarmBackground().ignoresSafeArea() }
        .navigationTitle("All memories")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary.opacity(0.35))
            TextField("Search your wins", text: $vm.searchText)
                .font(Typography.bodyLarge)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !vm.searchText.isEmpty {
                Button { vm.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.primary.opacity(0.25))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .modifier(SearchWell())
    }

    /// The field's ground: the recess a block sits in, which is what a box
    /// asking to be filled actually is. Extracted so `searchField` stays
    /// inside the type-checker's budget.
    private struct SearchWell: ViewModifier {
        func body(content: Content) -> some View {
            BlockWell(cell: 48) { content }
        }
    }

    // MARK: - Albums

    @ViewBuilder
    private var albums: some View {
        if vm.visibleSections.isEmpty {
            Text("Nothing matches that.")
                .font(Typography.bodySmall)
                .foregroundStyle(.primary.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else {
            ForEach(vm.visibleSections) { section in
                Text(section.title)
                    .font(Typography.caption2)
                    .kerning(0.8)
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.horizontal, GridConstants.horizontalPadding)
                    .padding(.top, 28)
                    .padding(.bottom, 10)

                LazyVGrid(columns: columns, spacing: 26) {
                    ForEach(section.albums) { album in
                        Button {
                            HapticsEngine.lightTap()
                            onOpenDay(album.id)
                        } label: {
                            DayAlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, GridConstants.horizontalPadding)
            }

            // Paging sentinel: reaching it loads the next eight weeks.
            if !vm.reachedEnd && vm.searchText.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear { vm.loadNextPage(context: modelContext) }
            }
        }
    }
}

/// One day in the grid: the cover, the day, the date.
private struct DayAlbumCard: View {
    let album: DayAlbum

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                AlbumCoverView(photoFileNames: album.photoFileNames, side: geo.size.width)
                Text(album.title)
                    .font(Typography.headerLarge)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)
                    .padding(.top, 13)
                Text(album.dateLabel)
                    .font(Typography.caption2)
                    .kerning(0.6)
                    .foregroundStyle(.primary.opacity(0.35))
                    .padding(.top, 3)
            }
        }
        .frame(height: cardHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(album.title), \(album.dateLabel), \(album.winCount) wins")
    }

    private var cardHeight: CGFloat {
        let coverSide = (UIScreen.main.bounds.width - GridConstants.horizontalPadding * 2 - 24) / 2
        return coverSide / AlbumCoverView.aspect + 62
    }
}
