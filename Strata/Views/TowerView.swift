import SwiftUI
import SwiftData

struct TowerView: View {
    let towerVM: TowerViewModel
    let onBlockTap: (PlacedBlock) -> Void

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let cellSize = GridConstants.cellSize(forGridWidth: availableWidth)
            let gridW = GridConstants.gridWidth(cellSize: cellSize)
            let gridH = GridConstants.gridHeight(rows: towerVM.totalRows, cellSize: cellSize)

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Completed blocks with cascade animation
                    ForEach(towerVM.placedBlocks) { block in
                        let f = block.frame(cellSize: cellSize)
                        CascadeBlockView(
                            block: block,
                            cellSize: cellSize,
                            isNewDrop: towerVM.newlyDroppedIDs.contains(block.id),
                            staggerDelay: towerVM.staggerDelay(for: block),
                            onTap: { onBlockTap(block) }
                        )
                        .offset(x: f.minX, y: f.minY)
                    }
                }
                .frame(width: gridW, height: max(gridH, 300))
                .padding(.top, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Cascade Animated Block

struct CascadeBlockView: View {
    let block: PlacedBlock
    let cellSize: CGFloat
    let isNewDrop: Bool
    let staggerDelay: Double
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        HabitBlockView(block: block, cellSize: cellSize, onTap: onTap)
            .scaleEffect(appeared || !isNewDrop ? 1.0 : 1.06)
            .offset(y: appeared || !isNewDrop ? 0 : -60)
            .opacity(appeared || !isNewDrop ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(block.habit.title), \(block.habit.category.rawValue), \(block.log.dateString)")
            .onAppear {
                if isNewDrop {
                    withAnimation(
                        GridConstants.cascadeReveal
                        .delay(staggerDelay)
                    ) {
                        appeared = true
                    }
                } else {
                    appeared = true
                }
            }
    }
}
