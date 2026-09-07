import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case today = "Today"
    case plan = "Plan"
    case insights = "Insights"

    var icon: String {
        switch self {
        case .tower: return "square.stack"
        case .today: return "calendar"
        case .plan: return "list.bullet.clipboard"
        case .insights: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.fill"
        case .today: return "calendar.fill"
        case .plan: return "list.bullet.clipboard.fill"
        case .insights: return "chart.bar.fill"
        }
    }
}
