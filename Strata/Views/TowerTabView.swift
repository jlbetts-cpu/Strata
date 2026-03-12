import SwiftUI
import SwiftData

struct TowerTabView: View {
    let towerVM: TowerViewModel
    let gamificationVM: GamificationViewModel
    let onBlockTap: (PlacedBlock) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // XP Bar
            XPBarView(
                level: gamificationVM.currentLevel,
                title: gamificationVM.levelTitle,
                progress: gamificationVM.levelProgress,
                xpInto: gamificationVM.xpIntoLevel,
                xpTotal: gamificationVM.xpForCurrentLevel
            )

            // Tower + Scrubber
            HStack(alignment: .top, spacing: 4) {
                TowerView(
                    towerVM: towerVM,
                    onBlockTap: onBlockTap
                )

                TowerScrubberView(
                    towerContentHeight: GridConstants.gridHeight(rows: towerVM.totalRows, cellSize: 80),
                    scrollOffset: 0,
                    viewportHeight: UIScreen.main.bounds.height,
                    heightMeters: towerVM.altimeterHeight,
                    topInset: 44,
                    onScrub: { _ in }
                )
                .frame(width: 40)
            }
            .padding(.horizontal, 12)
        }
    }
}
