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

            // Tower
            ZStack(alignment: .topTrailing) {
                TowerView(
                    towerVM: towerVM,
                    onBlockTap: onBlockTap
                )
                .padding(.horizontal, 12)

                AltimeterPill(heightMeters: towerVM.altimeterHeight)
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .opacity(towerVM.totalRows > 0 ? 1 : 0)
            }
        }
    }
}
