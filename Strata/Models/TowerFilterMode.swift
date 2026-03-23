import SwiftUI

enum TowerFilterMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

// Environment key so block views can read the active filter
private struct TowerFilterModeKey: EnvironmentKey {
    static let defaultValue: TowerFilterMode = .day
}

extension EnvironmentValues {
    var towerFilterMode: TowerFilterMode {
        get { self[TowerFilterModeKey.self] }
        set { self[TowerFilterModeKey.self] = newValue }
    }

    var perfectDayDates: Set<String> {
        get { self[PerfectDayDatesKey.self] }
        set { self[PerfectDayDatesKey.self] = newValue }
    }
}

private struct PerfectDayDatesKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}
