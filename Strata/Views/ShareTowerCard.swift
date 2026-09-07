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
    let blocks: [TowerBarChart.MiniBlock]
    let winCount: Int
    let date: Date

    /// Story size. Rendered at 3x for a 1080x1920 image.
    static let size = CGSize(width: 360, height: 640)

    private var rows: Int { blocks.map { $0.row + $0.rowSpan }.max() ?? 0 }

    var body: some View {
        ZStack {
            WarmBackground()

            // The whole composition is centred as ONE group.
            //
            // Pinning the count to the top and the tower to the bottom left
            // about a third of the card empty down the middle — which is not
            // minimalism, it is a gap. Keeping the two together and floating
            // the pair puts equal air above and below, and the eye reads a
            // caption and its picture rather than two things at opposite ends.
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(winCount)")
                            .font(.system(size: 64, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.85))
                        Text(winCount == 1 ? "win" : "wins")
                            .font(.system(size: 25, weight: .regular, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.28))
                }

                tower
            }
            .padding(.horizontal, 26)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    /// The blocks, scaled so the whole tower fits the card whatever its height.    /// The blocks, scaled so the whole tower fits the card whatever its height.
    ///
    /// A tall day and a short day both have to look composed, so the cell size
    /// is solved for rather than fixed — capped so three blocks do not become
    /// billboards.
    private var tower: some View {
        let columns = CGFloat(GridConstants.columnCount)
        let available = CGSize(width: Self.size.width - 52, height: Self.size.height * 0.58)
        let gap: CGFloat = 5
        let byWidth = (available.width - (columns - 1) * gap) / columns
        let byHeight = rows > 0
            ? (available.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            : byWidth
        let cell = min(byWidth, byHeight, 74)
        let w = columns * cell + (columns - 1) * gap
        let h = rows > 0 ? CGFloat(rows) * cell + CGFloat(rows - 1) * gap : 0

        return VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color.clear.frame(width: w, height: h)
                ForEach(blocks) { block in
                    blockShape(block, cell: cell, gap: gap)
                }
            }
            .frame(width: w, height: h)

            // The tower stands on its reflection here too.
            //
            // Without it the blocks float — a diagram of a tower rather than
            // the tower, and the one thing anyone who has used the app would
            // notice missing. It is the same trick the real page uses: the
            // shape again, flipped, faded to nothing.
            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: w, height: reflectionDepth)
                ForEach(bottomRow) { block in
                    blockShape(block, cell: cell, gap: gap, reflected: true)
                }
            }
            .frame(width: w, height: reflectionDepth, alignment: .topLeading)
            // Centre anchor, not `.top`. Flipping about the top edge maps
            // y to -y, which sent the whole reflection UPWARD out of its own
            // frame and drew nothing at all.
            .scaleEffect(y: -1)
            .mask(
                LinearGradient(
                    colors: [.black.opacity(0.30), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blur(radius: 1.5)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var reflectionDepth: CGFloat { 44 }

    /// Only the bottom row reaches the water — what is nearest is what
    /// reflects, and a full mirrored tower reads as a second tower.
    private var bottomRow: [TowerBarChart.MiniBlock] {
        blocks.filter { $0.row == 0 }
    }

    private func blockShape(
        _ block: TowerBarChart.MiniBlock,
        cell: CGFloat,
        gap: CGFloat,
        reflected: Bool = false
    ) -> some View {
        let bw = CGFloat(block.columnSpan) * cell + CGFloat(block.columnSpan - 1) * gap
        let bh = CGFloat(block.rowSpan) * cell + CGFloat(block.rowSpan - 1) * gap
        return RoundedRectangle(cornerRadius: cell * 0.147, style: .continuous)
            .fill(block.colour)
            .frame(width: bw, height: reflected ? min(bh, reflectionDepth) : bh)
            // The rim the tower's blocks wear, so the shared picture is the
            // same object rather than a flat diagram of it.
            .overlay {
                if !reflected {
                    RoundedRectangle(cornerRadius: cell * 0.147, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                }
            }
            .offset(
                x: CGFloat(block.column) * (cell + gap),
                y: reflected ? 0 : -CGFloat(block.row) * (cell + gap)
            )
    }
}

/// Renders the card to an image and hands it to the share sheet.
enum TowerShare {

    @MainActor
    static func image(blocks: [TowerBarChart.MiniBlock], winCount: Int, date: Date) -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareTowerCard(blocks: blocks, winCount: winCount, date: date)
        )
        // 3x gives 1080x1920 — the size stories are actually stored at, so the
        // platform never has to resample it.
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
