import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case today = "Today"
    case insights = "Insights"

    var icon: String {
        switch self {
        case .tower: return "square.stack"
        case .today: return "checklist"
        case .insights: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.fill"
        case .today: return "checklist"
        case .insights: return "chart.bar.fill"
        }
    }
}
