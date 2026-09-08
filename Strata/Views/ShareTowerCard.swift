import SwiftData
import SwiftUI
import UIKit

/// The tower, as something you can send to a friend.
///
/// **What makes a thing get shared** is not that it looks nice — it is that it
/// says something about the person posting it, in one glance, to people who
/// will never open the app. Three decisions follow from that:
///
/// 1. **The picture is the tower, at full size, and nothing else competes.**
///    No chrome, no app furniture, no stats panel. The blocks are already the
///    interesting object; anything added is something between the viewer and
///    it.
///
/// 2. **The number is large and the words are few.** A story gets about a
///    second and a half of attention. "9 wins today" is readable at a glance
///    and at a thumbnail; a caption is not.
///
/// 3. **It is 9:16.** Instagram and Snapchat stories are 1080x1920, and
///    anything squarer gets letterboxed into a shape the poster did not
///    choose. Rendering at the destination's aspect ratio is the difference
///    between a post someone made and a screenshot someone took.
///
/// Deliberately absent: a watermark, a QR code, a download prompt. An advert
/// in the middle of somebody's story is the fastest way to make them not post
/// it, and the tower is distinctive enough that anyone who wants to know what
/// it is will ask.
struct ShareTowerCard: View {
    let blocks: [PlacedBlock]
    let mergeGroups: [MergeGroup]
    let groupedIDs: Set<UUID>
    let coveredIDs: Set<UUID>
    let modelContext: ModelContext

    /// Story size. Rendered at 3x for a 1080x1920 image.
    static let size = CGSize(width: 360, height: 640)

    private var rows: Int { blocks.map { $0.row + $0.rowSpan }.max() ?? 0 }

    var body: some View {
        ZStack {
            WarmBackground()
            tower
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    /// The real tower, at whatever size fits the card.
    ///
    /// The blocks are `FlippableBlockView` — the same view the tower draws, so
    /// the card gets the rim, the frosted band, the contact shading, the
    /// merged runs and the photos, because it IS them. Rebuilding a simplified
    /// tower for the card meant maintaining a second one that would drift, and
    /// shipping a picture of the app that did not look like the app.
    ///
    /// The count and the date are gone with it. The blocks say how many there
    /// are by being there; a number beside them is the same fact twice, and a
    /// date is something the post already carries.
    private var tower: some View {
        let columns = CGFloat(GridConstants.columnCount)
        let spacing = GridConstants.spacing
        // Room for the tower and the water under it.
        let available = CGSize(
            width: Self.size.width - 44,
            height: Self.size.height - 96 - reflectionDepth
        )
        let byWidth = (available.width - (columns - 1) * spacing) / columns
        let byHeight = rows > 0
            ? (available.height - CGFloat(rows - 1) * spacing) / CGFloat(rows)
            : byWidth
        // Capped so three blocks do not become billboards.
        let cell = min(byWidth, byHeight, 82)
        let gridW = columns * cell + (columns - 1) * spacing
        let gridH = rows > 0 ? CGFloat(rows) * cell + CGFloat(rows - 1) * spacing : 0
        let radius = cell * 0.147

        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: gridW, height: gridH)

                ForEach(mergeGroups) { group in
                    MergedGroupView(
                        group: group,
                        cellSize: cell,
                        gridWidth: gridW,
                        gridHeight: gridH
                    )
                }

                ForEach(blocks) { block in
                    let f = GridConstants.blockFrame(
                        column: block.column, row: block.row,
                        columnSpan: block.columnSpan, rowSpan: block.rowSpan,
                        cellSize: cell
                    )
                    FlippableBlockView(
                        block: block,
                        width: f.width,
                        height: f.height,
                        cornerRadius: radius,
                        modelContext: modelContext,
                        isGroupMember: groupedIDs.contains(block.id),
                        isCovered: coveredIDs.contains(block.id)
                    )
                    .frame(width: f.width, height: f.height)
                    .offset(x: f.minX, y: gridH - f.minY - f.height)
                }
            }
            .frame(width: gridW, height: gridH)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var reflectionDepth: CGFloat { 0 }

    /// What of the tower reaches the water: the bottom row, as colour and
    /// width — the same rule the live page uses.
 }

/// Renders the card to an image and hands it to the share sheet.
enum TowerShare {

    @MainActor
    static func image(
        blocks: [PlacedBlock],
        mergeGroups: [MergeGroup],
        groupedIDs: Set<UUID>,
        coveredIDs: Set<UUID>,
        modelContext: ModelContext
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareTowerCard(
                blocks: blocks,
                mergeGroups: mergeGroups,
                groupedIDs: groupedIDs,
                coveredIDs: coveredIDs,
                modelContext: modelContext
            )
            // The card renders outside the tower's view tree, so the
            // environment the blocks read has to be handed to them.
            .environment(\.towerFilterMode, .day)
            .environment(\.perfectDayDates, [])
        )
        // 3x gives 1080x1920 — the size stories are actually stored at, so the
        // platform never has to resample it.
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
