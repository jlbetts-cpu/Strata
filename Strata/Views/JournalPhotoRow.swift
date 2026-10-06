import SwiftData
import SwiftUI

/// **The day's photographs, above the note** (the owner, 2026-10-06:
/// "something I have trouble doing is journalling each day... we have the
/// photo data already I feel we can use that to help the user fill out the
/// journal or want to dive deeper into their days").
///
/// A photograph is a retrieval cue: looking at one brings back what the day
/// held better than a blank page can (Henkel 2014; the photo-elicitation
/// literature), and the hard part of journaling with ADHD is starting, not
/// caring. So the note opens on the day's own pictures, and pressing one asks
/// Suggest's question about that win. It never writes anything.
///
/// Only when the day has photographs; otherwise the tab is as it was. Small
/// blocks on the block's own surface, so they read as the tower's wins.
struct JournalPhotoRow: View {
    let dateString: String
    /// The win a photograph belongs to, or nil for one with no name.
    let onPick: (String?) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var items: [Item] = []

    struct Item: Identifiable, Equatable {
        let id: UUID
        let title: String?
        let fileName: String
    }

    /// A Quick block's quarter: big enough to recognise, small enough that
    /// the note stays the page.
    static let side: CGFloat = 64
    /// No more than a glance holds; the rest scroll.
    static let limit = 12

    var body: some View {
        // A `ZStack` with a zero-size anchor, not a `Group`: modifiers on a
        // `Group` go to its children, and with no photographs yet there were
        // none, so the `.task` that would find them never ran.
        ZStack {
            Color.clear.frame(width: 0, height: 0)
            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GridConstants.spacing) {
                        ForEach(items) { item in
                            JournalPhotoTile(item: item) { onPick(item.title) }
                        }
                    }
                }
                .contentMargins(.horizontal, GridConstants.horizontalPadding, for: .scrollContent)
                .scrollClipDisabled()
                .frame(height: Self.side)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Today's photos")
                .padding(.top, GridConstants.gapTight)
                .padding(.bottom, GridConstants.gapItem)
            }
        }
        .task(id: dateString) { load() }
    }

    private func load() {
        let day = dateString
        var descriptor = FetchDescriptor<HabitLog>(
            predicate: #Predicate { $0.dateString == day && $0.imageFileName != nil },
            sortBy: [SortDescriptor(\.completedAt)])
        descriptor.relationshipKeyPathsForPrefetching = [\.habit]
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        items = logs.prefix(Self.limit).compactMap { log in
            guard let name = log.imageFileName else { return nil }
            let title = (log.habit?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let named = title.isEmpty || title == QuickWinService.untitled ? nil : title
            return Item(id: log.id, title: named, fileName: name)
        }
    }
}

private struct JournalPhotoTile: View {
    let item: JournalPhotoRow.Item
    let action: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        let side = JournalPhotoRow.side
        let radius = GridConstants.blockCornerRadius(forCell: side)
        Button {
            HapticsEngine.lightTap()
            action()
        } label: {
            BlockSurface(cornerRadius: radius, washOpacity: 0.06) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipped()
                } else {
                    Rectangle().fill(AppColors.inkPrimary.opacity(0.05))
                }
            }
            .frame(width: side, height: side)
        }
        .buttonStyle(.pressSurface)
        .accessibilityLabel(item.title.map { "Ask about \($0)" } ?? "Ask about this photo")
        .task(id: item.fileName) {
            image = await ImageManager.shared.loadThumbnail(fileName: item.fileName,
                                                            maxWidth: side * displayScale)
        }
    }
}
