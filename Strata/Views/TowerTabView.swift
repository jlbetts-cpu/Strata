import SwiftUI
import SwiftData

struct TowerTabView: View {
    let towerVM: TowerViewModel
    let gamificationVM: GamificationViewModel
    let onBlockTap: (PlacedBlock) -> Void
    let onIncompleteComplete: (Habit) -> Void

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

            // Tower + Altimeter
            HStack(alignment: .top, spacing: 4) {
                TowerView(
                    towerVM: towerVM,
                    onBlockTap: onBlockTap,
                    onIncompleteComplete: onIncompleteComplete
                )

                AltimeterView(
                    heightMeters: towerVM.altimeterHeight,
                    peakRows: towerVM.peakCompletedHeight
                )
                .frame(width: 40)
            }
            .padding(.horizontal, 12)
        }
    }
}
