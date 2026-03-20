import SwiftUI

struct TowerFilterPill: View {
    @Binding var selection: TowerFilterMode

    var body: some View {
        Picker("Filter", selection: $selection) {
            ForEach(TowerFilterMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}
