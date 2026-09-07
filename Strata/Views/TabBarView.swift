import SwiftUI

enum StrataTab: String, CaseIterable {
    case tower = "Tower"
    case insights = "Insights"

    var icon: String {
        switch self {
        case .tower: return "square.stack"
        case .insights: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .tower: return "square.stack.fill"
        case .insights: return "chart.bar.fill"
        }
    }
}
