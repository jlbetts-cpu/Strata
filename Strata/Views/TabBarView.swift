import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case today = "Today"
    case insights = "Insights"
    case preferences = "Preferences"

    var icon: String {
        switch self {
        case .tower: return "square.stack"
        case .today: return "calendar"
        case .insights: return "chart.bar"
        case .preferences: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.fill"
        case .today: return "calendar.fill"
        case .insights: return "chart.bar.fill"
        case .preferences: return "gearshape.fill"
        }
    }
}
