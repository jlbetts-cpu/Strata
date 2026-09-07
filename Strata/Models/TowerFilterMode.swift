import SwiftUI

enum TowerFilterMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    /// What the header shows. Short, because it sits beside a 40pt numeral and
    /// is a control rather than a title.
    var shortLabel: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
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
